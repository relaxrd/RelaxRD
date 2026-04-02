import itertools
import re
from collections import defaultdict, deque
from typing import Dict, List, Set, Tuple, Optional

from sql_metadata import Parser


# =========================================================
# 1. Helpers
# =========================================================

def normalize_col(col: str) -> str:
    col = str(col).strip()
    col = col.strip("`").strip('"')
    if "." in col:
        col = col.split(".")[-1]
    return col.strip()


def quote_col(col: str) -> str:
    return f"`{col}`"


def strip_alias(expr: str) -> str:
    expr = expr.strip()

    expr = re.sub(
        r"\s+AS\s+`?[A-Za-z_][A-Za-z0-9_]*`?\s*$",
        "",
        expr,
        flags=re.IGNORECASE,
    )

    expr = re.sub(
        r"(\))\s+`?[A-Za-z_][A-Za-z0-9_]*`?\s*$",
        r"\1",
        expr,
        flags=re.IGNORECASE,
    )

    expr = re.sub(
        r"^(`?[A-Za-z_][A-Za-z0-9_]*`?)\s+`?[A-Za-z_][A-Za-z0-9_]*`?\s*$",
        r"\1",
        expr,
        flags=re.IGNORECASE,
    )

    return expr.strip()


def split_top_level_csv(text: str) -> List[str]:
    parts = []
    cur = []
    depth = 0
    in_single = False
    in_double = False

    for ch in text:
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "(" and not in_single and not in_double:
            depth += 1
        elif ch == ")" and not in_single and not in_double:
            depth -= 1
        elif ch == "," and depth == 0 and not in_single and not in_double:
            parts.append("".join(cur).strip())
            cur = []
            continue
        cur.append(ch)

    if cur:
        parts.append("".join(cur).strip())
    return parts


def extract_identifiers_from_expr(expr: str) -> Set[str]:
    expr = re.sub(r"'[^']*'", " ", expr)
    expr = re.sub(r'"[^"]*"', " ", expr)

    tokens = re.findall(r"`[^`]+`|[A-Za-z_][A-Za-z0-9_]*", expr)

    keywords = {
        "SELECT", "FROM", "WHERE", "GROUP", "BY", "ORDER", "LIMIT", "HAVING",
        "AND", "OR", "NOT", "AS", "ASC", "DESC", "BETWEEN", "IN", "LIKE",
        "IS", "NULL", "DISTINCT", "COUNT", "AVG", "SUM", "MIN", "MAX",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
    }

    cols = set()
    for tok in tokens:
        t = tok.strip("`")
        if t.upper() not in keywords:
            cols.add(normalize_col(t))
    return cols


def indent_sql(text: str, n: int) -> str:
    pad = " " * n
    return "\n".join(pad + line if line.strip() else line for line in text.splitlines())


def replace_from_table(sql: str, old_table: str, new_table: str) -> str:
    pattern = rf"\bFROM\s+{re.escape(old_table)}\b"
    return re.sub(pattern, f"FROM {new_table}", sql, count=1, flags=re.IGNORECASE)


def replace_table_after_keyword(sql: str, keyword: str, new_table: str) -> str:
    pattern = rf"(\b{keyword}\s+)(`?[A-Za-z_][A-Za-z0-9_]*`?)"
    return re.sub(pattern, rf"\1{new_table}", sql, count=1, flags=re.IGNORECASE)


def strip_trailing_semicolon(sql: str) -> str:
    return sql.strip().rstrip(";").strip()


# =========================================================
# 2. SQL parsing
# =========================================================

def parse_sql(sql: str) -> Dict:
    sql_clean = re.sub(r"\s+", " ", sql.strip(), flags=re.MULTILINE)
    parser = Parser(sql_clean)

    table_name = parser.tables[0] if parser.tables else None
    parser_columns = {normalize_col(c) for c in parser.columns}

    m_select = re.search(r"\bSELECT\s+(.*?)\s+\bFROM\b", sql_clean, re.IGNORECASE)
    select_clause = m_select.group(1) if m_select else ""

    m_where = re.search(
        r"\bWHERE\s+(.*?)(?=\bGROUP\s+BY\b|\bORDER\s+BY\b|\bHAVING\b|\bLIMIT\b|$)",
        sql_clean,
        re.IGNORECASE,
    )
    where_clause = m_where.group(1).strip() if m_where else ""

    m_group = re.search(
        r"\bGROUP\s+BY\s+(.*?)(?=\bORDER\s+BY\b|\bHAVING\b|\bLIMIT\b|$)",
        sql_clean,
        re.IGNORECASE,
    )
    group_clause = m_group.group(1).strip() if m_group else ""

    m_order = re.search(
        r"\bORDER\s+BY\s+(.*?)(?=\bLIMIT\b|$)",
        sql_clean,
        re.IGNORECASE,
    )
    order_clause = m_order.group(1).strip() if m_order else ""

    m_having = re.search(
        r"\bHAVING\s+(.*?)(?=\bORDER\s+BY\b|\bLIMIT\b|$)",
        sql_clean,
        re.IGNORECASE,
    )
    having_clause = m_having.group(1).strip() if m_having else ""

    select_items = split_top_level_csv(select_clause) if select_clause else []
    group_items = split_top_level_csv(group_clause) if group_clause else []
    order_items = split_top_level_csv(order_clause) if order_clause else []

    projection_attrs = set()
    select_has_star = False
    for item in select_items:
        item = item.strip()
        if item == "*":
            select_has_star = True
            continue
        projection_attrs |= extract_identifiers_from_expr(strip_alias(item))

    predicate_attrs = extract_identifiers_from_expr(where_clause) if where_clause else set()

    group_attrs = set()
    for item in group_items:
        group_attrs |= extract_identifiers_from_expr(item)

    order_attrs = set()
    for item in order_items:
        order_attrs |= extract_identifiers_from_expr(strip_alias(item))

    having_attrs = extract_identifiers_from_expr(having_clause) if having_clause else set()

    clause_attrs = projection_attrs | predicate_attrs | group_attrs | order_attrs | having_attrs

    return {
        "stmt_type": "SELECT",
        "table_name": table_name,
        "projection_attrs": projection_attrs,
        "predicate_attrs": predicate_attrs,
        "group_attrs": group_attrs,
        "order_attrs": order_attrs,
        "having_attrs": having_attrs,
        "parser_columns": parser_columns,
        "required_attrs": clause_attrs | parser_columns,
        "select_has_star": select_has_star,
        "where_clause": where_clause,
        "raw_sql": sql.strip(),
    }


def parse_insert_sql(sql: str) -> Dict:
    sql_clean = re.sub(r"\s+", " ", sql.strip(), flags=re.MULTILINE)

    m = re.search(
        r"\bINSERT\s+INTO\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\s*$begin:math:text$\(\.\*\?\)$end:math:text$\s*\bVALUES\b\s*$begin:math:text$\(\.\*\)$end:math:text$\s*;?$",
        sql_clean,
        re.IGNORECASE,
    )
    if not m:
        raise ValueError(f"Cannot parse INSERT SQL:\n{sql}")

    table_name = normalize_col(m.group(1))
    cols = [normalize_col(c) for c in split_top_level_csv(m.group(2))]
    vals = split_top_level_csv(m.group(3))

    if len(cols) != len(vals):
        raise ValueError("INSERT columns and values count mismatch.")

    return {
        "stmt_type": "INSERT",
        "table_name": table_name,
        "insert_cols": cols,
        "insert_vals": vals,
        "col_val_map": dict(zip(cols, vals)),
        "raw_sql": sql.strip(),
    }


def parse_delete_sql(sql: str) -> Dict:
    sql_clean = re.sub(r"\s+", " ", sql.strip(), flags=re.MULTILINE)

    m = re.search(r"\bDELETE\s+FROM\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\b", sql_clean, re.IGNORECASE)
    if not m:
        raise ValueError(f"Cannot parse DELETE SQL:\n{sql}")

    table_name = normalize_col(m.group(1))

    m_where = re.search(r"\bWHERE\s+(.*?);?$", sql_clean, re.IGNORECASE)
    where_clause = m_where.group(1).strip() if m_where else ""
    where_attrs = extract_identifiers_from_expr(where_clause) if where_clause else set()

    return {
        "stmt_type": "DELETE",
        "table_name": table_name,
        "where_clause": where_clause,
        "where_attrs": where_attrs,
        "raw_sql": sql.strip(),
    }


def parse_update_sql(sql: str) -> Dict:
    sql_clean = re.sub(r"\s+", " ", sql.strip(), flags=re.MULTILINE)

    m = re.search(
        r"\bUPDATE\s+(`?[A-Za-z_][A-Za-z0-9_]*`?)\s+\bSET\b\s+(.*?)(?=\bWHERE\b|$)",
        sql_clean,
        re.IGNORECASE,
    )
    if not m:
        raise ValueError(f"Cannot parse UPDATE SQL:\n{sql}")

    table_name = normalize_col(m.group(1))
    set_clause = m.group(2).strip()

    m_where = re.search(r"\bWHERE\s+(.*?);?$", sql_clean, re.IGNORECASE)
    where_clause = m_where.group(1).strip() if m_where else ""

    assignments = split_top_level_csv(set_clause)
    set_map = {}
    for a in assignments:
        parts = a.split("=", 1)
        if len(parts) != 2:
            continue
        lhs = normalize_col(parts[0])
        rhs = parts[1].strip()
        set_map[lhs] = rhs

    where_attrs = extract_identifiers_from_expr(where_clause) if where_clause else set()

    return {
        "stmt_type": "UPDATE",
        "table_name": table_name,
        "set_map": set_map,
        "set_cols": set(set_map.keys()),
        "where_clause": where_clause,
        "where_attrs": where_attrs,
        "raw_sql": sql.strip(),
    }


# =========================================================
# 3. Join graph / relation cover
# =========================================================

def build_join_graph(relations: Dict[str, Set[str]]) -> Dict[str, Dict[str, Set[str]]]:
    graph = defaultdict(dict)
    rel_names = list(relations.keys())
    for i in range(len(rel_names)):
        for j in range(i + 1, len(rel_names)):
            r1, r2 = rel_names[i], rel_names[j]
            common = relations[r1] & relations[r2]
            if common:
                graph[r1][r2] = set(common)
                graph[r2][r1] = set(common)
    return graph


def covers_required(rel_subset: List[str], required_attrs: Set[str], relations: Dict[str, Set[str]]) -> bool:
    covered = set()
    for r in rel_subset:
        covered |= relations[r]
    return required_attrs <= covered


def is_connected_subset(rel_subset: List[str], graph: Dict[str, Dict[str, Set[str]]]) -> bool:
    if len(rel_subset) <= 1:
        return True
    subset = set(rel_subset)
    q = deque([rel_subset[0]])
    seen = {rel_subset[0]}
    while q:
        u = q.popleft()
        for v in graph.get(u, {}):
            if v in subset and v not in seen:
                seen.add(v)
                q.append(v)
    return seen == subset


def shortest_path(graph: Dict[str, Dict[str, Set[str]]], start: str, goal: str) -> List[str]:
    q = deque([(start, [start])])
    seen = {start}
    while q:
        u, path = q.popleft()
        if u == goal:
            return path
        for v in graph.get(u, {}):
            if v not in seen:
                seen.add(v)
                q.append((v, path + [v]))
    return []


def connect_subset_with_bridges(rel_subset: List[str], graph: Dict[str, Dict[str, Set[str]]]) -> Set[str]:
    subset = set(rel_subset)
    if not subset:
        return subset

    connected = {next(iter(subset))}
    remaining = subset - connected
    result = set(subset)

    while remaining:
        best_path = None
        for c in connected:
            for r in remaining:
                path = shortest_path(graph, c, r)
                if path and (best_path is None or len(path) < len(best_path)):
                    best_path = path

        if best_path is None:
            raise ValueError("Join graph is disconnected; cannot rewrite query.")

        result.update(best_path)
        connected.update(best_path)
        remaining = subset - connected

    return result


def find_minimal_join_relations(required_attrs: Set[str], relations: Dict[str, Set[str]]) -> List[str]:
    graph = build_join_graph(relations)
    rel_names = list(relations.keys())

    best_final = None
    best_width = None

    for k in range(1, len(rel_names) + 1):
        for subset in itertools.combinations(rel_names, k):
            subset = list(subset)
            if not covers_required(subset, required_attrs, relations):
                continue

            if is_connected_subset(subset, graph):
                final_set = set(subset)
            else:
                final_set = connect_subset_with_bridges(subset, graph)

            if not covers_required(list(final_set), required_attrs, relations):
                continue
            if not is_connected_subset(list(final_set), graph):
                continue

            width = sum(len(relations[r]) for r in final_set)

            if (
                best_final is None
                or len(final_set) < len(best_final)
                or (len(final_set) == len(best_final) and width < best_width)
            ):
                best_final = final_set
                best_width = width

        if best_final is not None:
            break

    if best_final is None:
        raise ValueError(f"Cannot find a connected cover for attrs: {required_attrs}")

    return sorted(best_final)


def build_join_tree_sql(selected_relations: List[str], relations: Dict[str, Set[str]]) -> str:
    graph = build_join_graph(relations)

    if not selected_relations:
        raise ValueError("No selected relations to join.")

    ordered = [selected_relations[0]]
    used = {selected_relations[0]}
    selected = set(selected_relations)

    while len(used) < len(selected):
        added = False
        for u in list(ordered):
            for v in selected_relations:
                if v in used:
                    continue
                common = graph.get(u, {}).get(v, set())
                if common:
                    ordered.append(v)
                    used.add(v)
                    added = True
                    break
            if added:
                break

        if not added:
            raise ValueError(f"Cannot build deterministic join order for: {selected_relations}")

    sql = ordered[0]
    used_order = [ordered[0]]

    for r in ordered[1:]:
        join_cols = set()
        for prev in used_order:
            join_cols |= graph.get(prev, {}).get(r, set())

        if not join_cols:
            raise ValueError(f"No join key found to connect relation {r}")

        cols_sql = ", ".join(quote_col(c) for c in sorted(join_cols))
        sql += f"\nJOIN {r} USING ({cols_sql})"
        used_order.append(r)

    return sql


# =========================================================
# 4. SELECT rewriting
# =========================================================

def build_subquery_for_relaxrd(parsed: Dict,
                               relations: Dict[str, Set[str]],
                               original_schema: Set[str],
                               residual_table: str,
                               include_residual: bool = True) -> Tuple[str, List[str]]:
    clause_attrs = (
        set(parsed.get("projection_attrs", set()))
        | set(parsed.get("predicate_attrs", set()))
        | set(parsed.get("group_attrs", set()))
        | set(parsed.get("order_attrs", set()))
        | set(parsed.get("having_attrs", set()))
    )

    parser_attrs = set(parsed.get("parser_columns", set()))
    parser_attrs = {a for a in parser_attrs if a in original_schema}

    if parsed.get("select_has_star", False):
        required_attrs = set(original_schema)
    else:
        required_attrs = clause_attrs | parser_attrs
        required_attrs = {a for a in required_attrs if a in original_schema}

    if not required_attrs:
        raise ValueError("No valid required attributes remain after schema filtering.")

    selected_relations = find_minimal_join_relations(required_attrs, relations)

    projected_cols = ", ".join(quote_col(c) for c in sorted(required_attrs))
    from_sql = build_join_tree_sql(selected_relations, relations)

    decomposed_sql = f"SELECT {projected_cols}\nFROM {from_sql}"

    if include_residual:
        residual_sql = f"SELECT {projected_cols}\nFROM {residual_table}"
        subquery = decomposed_sql + "\nUNION ALL\n" + residual_sql
    else:
        subquery = decomposed_sql

    return subquery, selected_relations


def rewrite_sql_with_cte(sql: str,
                         input_table_in_original_sql: str,
                         logical_rewritten_table: str,
                         relations: Dict[str, Set[str]],
                         original_schema: Set[str],
                         residual_table: str,
                         include_residual: bool = True) -> str:
    parsed = parse_sql(sql)
    subquery, _ = build_subquery_for_relaxrd(
        parsed=parsed,
        relations=relations,
        original_schema=original_schema,
        residual_table=residual_table,
        include_residual=include_residual,
    )

    rewritten_outer_sql = replace_from_table(
        sql.strip(),
        input_table_in_original_sql,
        logical_rewritten_table
    )

    return (
        f"WITH {logical_rewritten_table} AS (\n"
        f"{indent_sql(subquery, 4)}\n"
        f")\n"
        f"{rewritten_outer_sql}"
    )


def rewrite_sql_inline(sql: str,
                       input_table_in_original_sql: str,
                       logical_rewritten_table: str,
                       relations: Dict[str, Set[str]],
                       original_schema: Set[str],
                       residual_table: str,
                       include_residual: bool = True) -> str:
    parsed = parse_sql(sql)
    subquery, _ = build_subquery_for_relaxrd(
        parsed=parsed,
        relations=relations,
        original_schema=original_schema,
        residual_table=residual_table,
        include_residual=include_residual,
    )

    pattern = rf"\bFROM\s+{re.escape(input_table_in_original_sql)}\b"
    replacement = f"FROM (\n{indent_sql(subquery, 4)}\n) AS {logical_rewritten_table}"
    return re.sub(pattern, replacement, sql.strip(), count=1, flags=re.IGNORECASE)


# =========================================================
# 5. DML rewriting
# =========================================================

def rewrite_insert_to_r0(sql: str,
                         input_table_in_original_sql: str,
                         residual_table: str) -> str:
    """
    INSERT INTO original_table (...) VALUES (...)
    -> INSERT INTO r0 (...) VALUES (...)
    """
    sql_no_semicolon = strip_trailing_semicolon(sql)
    sql_rewritten = replace_table_after_keyword(sql_no_semicolon, "INSERT INTO", residual_table)
    return sql_rewritten + ";"


def build_key_match_condition(alias: str, key_columns: List[str], source_alias: Optional[str] = None) -> str:
    if source_alias:
        return " AND ".join(
            f"{alias}.{quote_col(c)} = {source_alias}.{quote_col(c)}"
            for c in key_columns
        )
    return " AND ".join(f"{alias}.{quote_col(c)} = src.{quote_col(c)}" for c in key_columns)


def rewrite_delete_via_select(sql: str,
                              input_table_in_original_sql: str,
                              logical_rewritten_table: str,
                              relations: Dict[str, Set[str]],
                              original_schema: Set[str],
                              residual_table: str,
                              main_table: str,
                              key_columns: List[str],
                              include_residual: bool = True) -> str:
    """
    MySQL/PolarDB-safe DELETE rewriting:
    - main_table: delete by key lookup through reconstructed logical relation
    - residual_table r0: delete directly using original WHERE clause
    """
    parsed = parse_delete_sql(sql)

    fake_select = f"SELECT {', '.join(quote_col(c) for c in key_columns)} FROM {input_table_in_original_sql}"
    if parsed["where_clause"]:
        fake_select += f" WHERE {parsed['where_clause']}"

    fake_parsed = parse_sql(fake_select)

    subquery_body, _ = build_subquery_for_relaxrd(
        parsed=fake_parsed,
        relations=relations,
        original_schema=original_schema,
        residual_table=residual_table,
        include_residual=include_residual,
    )

    target_keys_sql = (
        f"SELECT DISTINCT {', '.join(quote_col(c) for c in key_columns)}\n"
        f"FROM (\n{indent_sql(subquery_body, 4)}\n) AS {logical_rewritten_table}"
    )
    if parsed["where_clause"]:
        target_keys_sql += f"\nWHERE {parsed['where_clause']}"

    main_delete = (
        f"DELETE FROM {main_table}\n"
        f"WHERE EXISTS (\n"
        f"    SELECT 1\n"
        f"    FROM (\n{indent_sql(target_keys_sql, 8)}\n    ) AS src\n"
        f"    WHERE " + " AND ".join(
            f"{main_table}.{quote_col(c)} = src.{quote_col(c)}" for c in key_columns
        ) + "\n"
        f");"
    )

    if parsed["where_clause"]:
        residual_delete = (
            f"DELETE FROM {residual_table}\n"
            f"WHERE {parsed['where_clause']};"
        )
    else:
        residual_delete = f"DELETE FROM {residual_table};"

    return main_delete + "\n" + residual_delete


def rewrite_update_via_delete_insert(sql: str,
                                     input_table_in_original_sql: str,
                                     logical_rewritten_table: str,
                                     relations: Dict[str, Set[str]],
                                     original_schema: Set[str],
                                     residual_table: str,
                                     main_table: str,
                                     key_columns: List[str],
                                     include_residual: bool = True) -> str:
    """
    MySQL/PolarDB-safe UPDATE rewriting:
    UPDATE = select old full rows + delete old rows + insert updated full rows into r0
    Every statement uses its own inline subquery, no shared CTE.
    """
    parsed = parse_update_sql(sql)
    full_cols = sorted(original_schema)

    full_select = f"SELECT {', '.join(quote_col(c) for c in full_cols)} FROM {input_table_in_original_sql}"
    if parsed["where_clause"]:
        full_select += f" WHERE {parsed['where_clause']}"

    fake_parsed = parse_sql(full_select)

    subquery_body, _ = build_subquery_for_relaxrd(
        parsed=fake_parsed,
        relations=relations,
        original_schema=original_schema,
        residual_table=residual_table,
        include_residual=include_residual,
    )

    old_rows_sql = (
        f"SELECT {', '.join(quote_col(c) for c in full_cols)}\n"
        f"FROM (\n{indent_sql(subquery_body, 4)}\n) AS {logical_rewritten_table}"
    )
    if parsed["where_clause"]:
        old_rows_sql += f"\nWHERE {parsed['where_clause']}"

    # delete from main_table
    main_delete = (
        f"DELETE FROM {main_table}\n"
        f"WHERE EXISTS (\n"
        f"    SELECT 1\n"
        f"    FROM (\n{indent_sql(old_rows_sql, 8)}\n    ) AS src\n"
        f"    WHERE " + " AND ".join(
            f"{main_table}.{quote_col(c)} = src.{quote_col(c)}" for c in key_columns
        ) + "\n"
        f");"
    )

    # delete from residual
    if parsed["where_clause"]:
        residual_delete = (
            f"DELETE FROM {residual_table}\n"
            f"WHERE {parsed['where_clause']};"
        )
    else:
        residual_delete = f"DELETE FROM {residual_table};"

    # build updated rows select
    new_row_exprs = []
    for c in full_cols:
        if c in parsed["set_map"]:
            new_row_exprs.append(f"{parsed['set_map'][c]} AS {quote_col(c)}")
        else:
            new_row_exprs.append(f"src.{quote_col(c)} AS {quote_col(c)}")

    new_rows_sql = (
        f"SELECT\n    " + ",\n    ".join(new_row_exprs) + "\n"
        f"FROM (\n{indent_sql(old_rows_sql, 4)}\n) AS src"
    )

    residual_insert = (
        f"INSERT INTO {residual_table} ({', '.join(quote_col(c) for c in full_cols)})\n"
        f"{new_rows_sql};"
    )

    return main_delete + "\n" + residual_delete + "\n" + residual_insert


# =========================================================
# 6. Block-level wrapper
# =========================================================

def rewrite_sql_block(block: str,
                      original_schema: Set[str],
                      relations: Dict[str, Set[str]],
                      input_table_in_original_sql: str,
                      logical_rewritten_table: str,
                      residual_table: str,
                      include_residual: bool = True,
                      mode: str = "cte",
                      main_table: Optional[str] = None,
                      key_columns: Optional[List[str]] = None) -> str:
    lines = block.splitlines()
    comment_lines = [ln for ln in lines if ln.strip().startswith("--")]
    sql_lines = [ln for ln in lines if not ln.strip().startswith("--")]
    sql_stmt = "\n".join(sql_lines).strip()

    if not sql_stmt:
        return block

    stmt_type = sql_stmt.strip().split()[0].upper()

    if stmt_type == "SELECT":
        if mode == "inline":
            rewritten_sql = rewrite_sql_inline(
                sql=sql_stmt,
                input_table_in_original_sql=input_table_in_original_sql,
                logical_rewritten_table=logical_rewritten_table,
                relations=relations,
                original_schema=original_schema,
                residual_table=residual_table,
                include_residual=include_residual,
            )
        else:
            rewritten_sql = rewrite_sql_with_cte(
                sql=sql_stmt,
                input_table_in_original_sql=input_table_in_original_sql,
                logical_rewritten_table=logical_rewritten_table,
                relations=relations,
                original_schema=original_schema,
                residual_table=residual_table,
                include_residual=include_residual,
            )

    elif stmt_type == "INSERT":
        rewritten_sql = rewrite_insert_to_r0(
            sql=sql_stmt,
            input_table_in_original_sql=input_table_in_original_sql,
            residual_table=residual_table,
        )

    elif stmt_type == "DELETE":
        if not main_table or not key_columns:
            raise ValueError("DELETE rewriting requires main_table and key_columns.")
        rewritten_sql = rewrite_delete_via_select(
            sql=sql_stmt,
            input_table_in_original_sql=input_table_in_original_sql,
            logical_rewritten_table=logical_rewritten_table,
            relations=relations,
            original_schema=original_schema,
            residual_table=residual_table,
            main_table=main_table,
            key_columns=key_columns,
            include_residual=include_residual,
        )

    elif stmt_type == "UPDATE":
        if not main_table or not key_columns:
            raise ValueError("UPDATE rewriting requires main_table and key_columns.")
        rewritten_sql = rewrite_update_via_delete_insert(
            sql=sql_stmt,
            input_table_in_original_sql=input_table_in_original_sql,
            logical_rewritten_table=logical_rewritten_table,
            relations=relations,
            original_schema=original_schema,
            residual_table=residual_table,
            main_table=main_table,
            key_columns=key_columns,
            include_residual=include_residual,
        )

    else:
        return block

    if comment_lines:
        return "\n".join(comment_lines) + "\n" + rewritten_sql
    return rewritten_sql