from pathlib import Path
import json
import pickle
import re
try:
    import pandas as pd
except ImportError:
    pd = None

import util as tr


# =========================================================
# 1. Root paths
# =========================================================

COREAFD_ROOT = Path(
    "CoreAFD/output"
)

RELAXRD_ROOT = Path(
    "RelaxRD/output"
)

SQL_ROOT = Path(
    "Query_Performance/Workload/Original"
)


# =========================================================
# 2. Names used in rewriting
# =========================================================

INPUT_TABLE_IN_ORIGINAL_SQL = "r0"
LOGICAL_REWRITTEN_TABLE = "r_original"
RESIDUAL_TABLE = "r0"


# =========================================================
# 3. Dataset config
#   !!! 请把 main_table 和 key_columns 改成你的真实值 !!!
# =========================================================

DATASETS = [
    # {
    #     "display_name": "Adult",
    #     "relaxrd_name": "adult",
    #     "pkl_name": "adult_coreafd.pkl",
    #     "key_columns": ["a3"],
    # },
    # {
    #     "display_name": "CrimeLA",
    #     "relaxrd_name": "Crime",
    #     "pkl_name": "Crime_coreafd.pkl",
    #     "key_columns": ["Digital Record Number"],
    # },
    # {
    #     "display_name": "DIGIX",
    #     "relaxrd_name": "DIGIX",
    #     "pkl_name": "DIGIX_coreafd.pkl",
    #     "key_columns": ["id"],
    # },
    {
        "display_name": "fraudTrain",
        "relaxrd_name": "fraudTrain",
        "pkl_name": "fraudTrain_coreafd.pkl",
        "key_columns": ["trans_num"],
    },
    # {
    #     "display_name": "Iowa",
    #     "relaxrd_name": "Iowa",
    #     "pkl_name": "Iowa_coreafd.pkl",
    #     "key_columns": ["Invoice/Item Number"],
    # },
    # {
    #     "display_name": "NCVoter",
    #     "relaxrd_name": "Ncvoter",
    #     "pkl_name": "Ncvoter_coreafd.pkl",
    #     "key_columns": ["ncid"],
    # },
    # {
    #     "display_name": "School",
    #     "relaxrd_name": "school",
    #     "pkl_name": "school_coreafd.pkl",
    #     "key_columns": ["year", "district", "school"],
    # },
    # {
    #     "display_name": "IndusData",
    #     "relaxrd_name": "IndusData",
    #     "pkl_name": "IndusData_coreafd.pkl",
    #     "key_columns": ["uin", "docid", "timestamp_laqu"],
    # },
]
def infer_main_table(decomposed_relations: dict) -> str:
    """
    Infer R_{k+1} as the relation whose name has the largest numeric suffix.
    Example: r1, r2, r3 -> r3
    """
    candidates = []

    for rel_name in decomposed_relations.keys():
        m = re.fullmatch(r"[Rr](\d+)", rel_name)
        if m:
            candidates.append((int(m.group(1)), rel_name))

    if not candidates:
        raise ValueError(
            "Cannot infer main_table automatically: no relation names like r1/r2/... found."
        )

    candidates.sort(key=lambda x: x[0])
    return candidates[-1][1]

# =========================================================
# 4. Local helpers
# =========================================================

def normalize_col(col: str) -> str:
    col = str(col).strip()
    col = col.strip("`").strip('"')
    if "." in col:
        col = col.split(".")[-1]
    return col.strip()


def load_coreafd_pkl(path: Path):
    with open(path, "rb") as f:
        return pickle.load(f)


def try_read_columns_from_file(path: Path):
    suffix = path.suffix.lower()

    try:
        if suffix == ".csv":
            if pd is None:
                return None
            df = pd.read_csv(path, nrows=0)
            return [normalize_col(c) for c in df.columns]

        if suffix == ".parquet":
            if pd is None:
                return None
            df = pd.read_parquet(path)
            return [normalize_col(c) for c in df.columns]

        if suffix == ".json":
            with open(path, "r", encoding="utf-8") as f:
                obj = json.load(f)

            if isinstance(obj, dict):
                if "columns" in obj and isinstance(obj["columns"], list):
                    return [normalize_col(c) for c in obj["columns"]]
                if "attrs" in obj and isinstance(obj["attrs"], list):
                    return [normalize_col(c) for c in obj["attrs"]]

            if isinstance(obj, list) and len(obj) > 0 and isinstance(obj[0], dict):
                return [normalize_col(c) for c in obj[0].keys()]

        if suffix == ".pkl":
            with open(path, "rb") as f:
                obj = pickle.load(f)

            if hasattr(obj, "columns"):
                return [normalize_col(c) for c in obj.columns]

            if isinstance(obj, dict):
                if "columns" in obj and isinstance(obj["columns"], list):
                    return [normalize_col(c) for c in obj["columns"]]
                if "attrs" in obj and isinstance(obj["attrs"], list):
                    return [normalize_col(c) for c in obj["attrs"]]
                if "schema" in obj and isinstance(obj["schema"], list):
                    return [normalize_col(c) for c in obj["schema"]]

            if isinstance(obj, list):
                if all(isinstance(x, str) for x in obj):
                    return [normalize_col(c) for c in obj]

    except Exception:
        return None

    return None


def discover_first_schema_file(path: Path):
    if path.is_file():
        return path

    candidates = []
    for p in path.rglob("*"):
        if p.is_file() and p.suffix.lower() in {".csv", ".parquet", ".json", ".pkl"}:
            candidates.append(p)

    if not candidates:
        return None

    candidates.sort(key=lambda x: (len(x.relative_to(path).parts), x.name.lower()))
    return candidates[0]


def load_relaxrd_schemas(dataset_relaxrd_dir: Path):
    """
    返回:
        original_schema: residual/full table r0 的列集合
        decomposed_relations: 其他子表的列集合 dict
    """
    if not dataset_relaxrd_dir.exists():
        raise FileNotFoundError(f"RelaxRD dir not found: {dataset_relaxrd_dir}")

    relation_schemas = {}

    for child in sorted(dataset_relaxrd_dir.iterdir(), key=lambda x: x.name.lower()):
        if child.name.startswith("."):
            continue

        relation_name = child.stem if child.is_file() else child.name
        schema_file = discover_first_schema_file(child)
        if schema_file is None:
            continue

        cols = try_read_columns_from_file(schema_file)
        if cols:
            relation_schemas[relation_name] = set(cols)

    if not relation_schemas:
        raise ValueError(f"No relation schemas found under {dataset_relaxrd_dir}")

    if RESIDUAL_TABLE not in relation_schemas:
        raise ValueError(f"Residual/full table '{RESIDUAL_TABLE}' not found under {dataset_relaxrd_dir}")

    original_schema = relation_schemas[RESIDUAL_TABLE]
    decomposed_relations = {
        t: cols for t, cols in relation_schemas.items()
        if t != RESIDUAL_TABLE
    }

    if not decomposed_relations:
        raise ValueError(f"No decomposed relations found under {dataset_relaxrd_dir}")

    return original_schema, decomposed_relations


def choose_sql_file(dataset_sql_dir: Path):
    sql_files = [p for p in dataset_sql_dir.glob("*.sql")]
    if not sql_files:
        raise FileNotFoundError(f"No .sql files found in {dataset_sql_dir}")

    preferred = []
    for p in sql_files:
        lname = p.name.lower()
        if "duckdb" in lname:
            continue
        if "coreafd" in lname:
            continue
        if "latency" in lname or "planjson" in lname:
            continue
        preferred.append(p)

    if len(preferred) == 1:
        return preferred[0]

    if len(preferred) > 1:
        single = [p for p in preferred if "single" in p.name.lower()]
        if len(single) == 1:
            return single[0]
        return sorted(preferred)[0]

    return sorted(sql_files)[0]


def split_sql_file_with_comments(sql_text: str):
    lines = sql_text.splitlines()
    blocks = []

    current_comments = []
    current_sql = []

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("--") or stripped == "":
            if not current_sql:
                current_comments.append(line)
            else:
                current_sql.append(line)
            continue

        current_sql.append(line)

        if ";" in line:
            block = "\n".join(current_comments + current_sql).strip()
            if block:
                blocks.append(block)
            current_comments = []
            current_sql = []

    tail = "\n".join(current_comments + current_sql).strip()
    if tail:
        blocks.append(tail)

    return blocks


def extract_sql_statement_only(block: str):
    lines = block.splitlines()
    sql_lines = [ln for ln in lines if not ln.strip().startswith("--")]
    return "\n".join(sql_lines).strip()


def format_relation_schema(name: str, cols: set) -> str:
    cols_sorted = sorted(cols)
    return f"{name}(" + ", ".join(cols_sorted) + ")"

def build_dataset_report(display_name: str,
                         pkl_path: Path,
                         original_schema: set,
                         decomposed_relations: dict,
                         main_table: str,
                         key_columns: list,
                         sql_file: Path,
                         original_blocks: list,
                         rewritten_blocks: list) -> str:
    lines = []
    lines.append(f"Dataset: {display_name}")
    lines.append(f"CoreAFD pkl: {pkl_path}")
    lines.append(f"Original SQL file: {sql_file}")
    lines.append(f"Main table (R_k+1): {main_table}")
    lines.append(f"Key columns: {key_columns}")
    lines.append("")

    lines.append("=== Original Schema ===")
    lines.append(format_relation_schema(RESIDUAL_TABLE, original_schema))
    lines.append("")

    lines.append("=== Decomposed Schemas ===")
    for rel_name in sorted(decomposed_relations.keys()):
        lines.append(format_relation_schema(rel_name, decomposed_relations[rel_name]))
    lines.append("")

    lines.append("=== SQL Rewriting Details ===")
    for idx, (orig_block, rew_block) in enumerate(zip(original_blocks, rewritten_blocks), start=1):
        lines.append(f"--- Statement {idx} ---")
        lines.append("[Original]")
        lines.append(orig_block.strip())
        lines.append("")
        lines.append("[Rewritten]")
        lines.append(rew_block.strip())
        lines.append("")
        lines.append("=" * 80)
        lines.append("")

    return "\n".join(lines)


def rewrite_sql_block_local(block: str,
                            original_schema: set,
                            relations: dict,
                            input_table_in_original_sql: str,
                            logical_rewritten_table: str,
                            residual_table: str,
                            main_table: str,
                            key_columns: list,
                            include_residual: bool = True,
                            mode: str = "cte"):
    sql_stmt = extract_sql_statement_only(block)
    if not sql_stmt:
        return block

    rewritten_sql = tr.rewrite_sql_block(
        block=block,
        original_schema=original_schema,
        relations=relations,
        input_table_in_original_sql=input_table_in_original_sql,
        logical_rewritten_table=logical_rewritten_table,
        residual_table=residual_table,
        include_residual=include_residual,
        mode=mode,
        main_table=main_table,
        key_columns=key_columns,
    )
    return rewritten_sql


# =========================================================
# 5. Process one dataset
# =========================================================

def process_one_dataset(cfg: dict):
    display_name = cfg["display_name"]
    relaxrd_name = cfg["relaxrd_name"]
    pkl_name = cfg["pkl_name"]
    key_columns = cfg["key_columns"]

    dataset_sql_dir = SQL_ROOT / display_name
    dataset_relaxrd_dir = RELAXRD_ROOT / relaxrd_name
    dataset_pkl_path = COREAFD_ROOT / pkl_name

    if not dataset_sql_dir.exists():
        raise FileNotFoundError(f"SQL dir not found: {dataset_sql_dir}")
    if not dataset_relaxrd_dir.exists():
        raise FileNotFoundError(f"RelaxRD dir not found: {dataset_relaxrd_dir}")

    if dataset_pkl_path.exists():
        try:
            _ = load_coreafd_pkl(dataset_pkl_path)
        except Exception as e:
            print(f"[WARN] failed to load pkl for {display_name}: {e}")
    else:
        print(f"[WARN] pkl not found for {display_name}: {dataset_pkl_path}")

    original_schema, decomposed_relations = load_relaxrd_schemas(dataset_relaxrd_dir)


    main_table = infer_main_table(decomposed_relations)

    if main_table not in decomposed_relations:
        raise ValueError(f"Inferred main_table '{main_table}' not found in decomposed relations for {display_name}")

    sql_file = choose_sql_file(dataset_sql_dir)

    with open(sql_file, "r", encoding="utf-8") as f:
        sql_text = f.read()

    original_blocks = split_sql_file_with_comments(sql_text)
    rewritten_blocks = []

    for block in original_blocks:
        sql_stmt = extract_sql_statement_only(block)
        if not sql_stmt:
            rewritten_blocks.append(block)
            continue

        rewritten = rewrite_sql_block_local(
            block=block,
            original_schema=original_schema,
            relations=decomposed_relations,
            input_table_in_original_sql=INPUT_TABLE_IN_ORIGINAL_SQL,
            logical_rewritten_table=LOGICAL_REWRITTEN_TABLE,
            residual_table=RESIDUAL_TABLE,
            main_table=main_table,
            key_columns=key_columns,
            include_residual=True,
            mode="cte",
        )
        rewritten_blocks.append(rewritten)

    # 1) 输出改写后的 sql 文件
    output_sql_file = dataset_sql_dir / f"{display_name}_coreafd.sql"
    with open(output_sql_file, "w", encoding="utf-8") as f:
        f.write("\n\n".join(rewritten_blocks).strip() + "\n")

    # 2) 输出检查 report
    report_text = build_dataset_report(
        display_name=display_name,
        pkl_path=dataset_pkl_path,
        original_schema=original_schema,
        decomposed_relations=decomposed_relations,
        main_table=main_table,
        key_columns=key_columns,
        sql_file=sql_file,
        original_blocks=original_blocks,
        rewritten_blocks=rewritten_blocks,
    )

    report_file = dataset_sql_dir / f"{display_name}_rewrite_log.txt"
    with open(report_file, "w", encoding="utf-8") as f:
        f.write(report_text)

    print(f"[OK] {display_name} -> {output_sql_file}")
    print(f"[OK] {display_name} report -> {report_file}")
    print(f"[INFO] {display_name}: inferred main_table = {main_table}")

# =========================================================
# 6. Batch loop
# =========================================================

def main():
    for cfg in DATASETS:
        try:
            process_one_dataset(cfg)
        except Exception as e:
            print(f"[ERROR] {cfg['display_name']}: {e}")


if __name__ == "__main__":
    main()