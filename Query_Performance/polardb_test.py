import pymysql
import time
import csv
import re
from pathlib import Path
import json


# ===============================
# 1. Config
# ===============================
DB_CONFIGS = [
    {
        "db_name": "fraud_none_db",
        "label": "none",
    },
    {
        "db_name": "fraud_Zlib_db",
        "label": "Zlib",
    },
]

sql_file = Path(
    "/Users/rebeccading/Library/CloudStorage/OneDrive-个人/10-source_code/Sydney/RelaxRD_vldb_revision/sql/tencent/tencent.sql"
)

RUN_TIMES = 3  # 每个SQL执行次数


# ===============================
# 2. Parse SQL file
# ===============================
def parse_sql_file(path: Path):
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    items = []
    current_comments = []
    current_sql_lines = []

    for line in lines:
        stripped = line.strip()

        if stripped.startswith("--"):
            if not current_sql_lines:
                current_comments.append(line)
            continue

        if stripped == "":
            continue

        current_sql_lines.append(line)

        if ";" in line:
            sql_text = "\n".join(current_sql_lines).strip()
            comment_text = "\n".join(current_comments).strip()

            m = re.search(r"\bQ(\d+)\b", comment_text, re.IGNORECASE)
            query_id = f"Q{m.group(1)}" if m else f"Q{len(items)+1}"

            items.append({
                "query_id": query_id,
                "comment": comment_text,
                "sql": sql_text
            })

            current_comments = []
            current_sql_lines = []

    return items


# ===============================
# 3. Helpers
# ===============================
def get_connection(db_name: str):
    return pymysql.connect(
        host="polardb-rebeccading.rwlb.rds.aliyuncs.com",
        port=3306,
        user="rebeccading",
        password="Dinry123!",
        database=db_name,
        charset="utf8mb4",
        autocommit=False
    )


def get_sql_type(sql: str):
    return sql.strip().split()[0].upper()


def get_explain_json_output(cursor, sql: str):
    explain_sql = "EXPLAIN FORMAT=JSON " + sql
    cursor.execute(explain_sql)

    row = cursor.fetchone()
    if row is None:
        return ""

    plan_text = str(row[0])

    try:
        parsed = json.loads(plan_text)
        return json.dumps(parsed, ensure_ascii=False)
    except Exception:
        return plan_text



def wrap_count_query(sql: str) -> str:
    sql = sql.strip().rstrip(";")
    return f"SELECT COUNT(*) FROM ({sql}) AS subq"


def run_and_measure(cursor, sql: str, sql_type: str):
    start = time.perf_counter()

    if sql_type == "SELECT":
        try:
            count_sql = wrap_count_query(sql)
            cursor.execute(count_sql)
            result = cursor.fetchone()
            cardinality = result[0] if result else 0
        except Exception:
            cardinality = ""

    else:
        cursor.execute(sql)
        rc = cursor.rowcount
        cardinality = rc if isinstance(rc, int) else ""

    latency = time.perf_counter() - start

    return latency, cardinality



# ===============================
# 4. Benchmark one database
# ===============================
def benchmark_one_db(db_name: str, sql_file: Path, run_times: int):
    print(f"\n==============================")
    print(f"Start benchmarking: {db_name}")
    print(f"SQL file: {sql_file}")
    print(f"==============================")

    queries = parse_sql_file(sql_file)

    conn = get_connection(db_name)
    cursor = conn.cursor()

    output_dir = sql_file.parent
    csv_file = output_dir / f"{db_name}_latency_planjson.csv"

    if csv_file.exists():
        csv_file.unlink()

    results = []

    try:
        for item in queries:
            query_id = item["query_id"]
            sql = item["sql"]
            sql_type = get_sql_type(sql)

            run_latencies = []
            cardinality = ""
            error = ""
            plan = ""

            try:
                # 先拿 plan
                plan = get_explain_json_output(cursor, sql)
                conn.rollback()

                for _ in range(run_times):
                    latency, cardinality = run_and_measure(cursor, sql, sql_type)
                    conn.rollback()
                    run_latencies.append(latency)

                latency_avg = sum(run_latencies) / run_times

                print(
                    f"{db_name} | {query_id} | {sql_type} | rows={cardinality} | "
                    f"runs={[round(x, 6) for x in run_latencies]} | avg={latency_avg:.6f}s"
                )

            except Exception as e:
                conn.rollback()
                error = str(e)
                latency_avg = ""

                while len(run_latencies) < run_times:
                    run_latencies.append("")

                print(f"{db_name} | {query_id} | {sql_type} | ERROR | {error}")

            results.append({
                "db_name": db_name,
                "query_id": query_id,
                "type": sql_type,
                "latency_run1": run_latencies[0] if len(run_latencies) > 0 else "",
                "latency_run2": run_latencies[1] if len(run_latencies) > 1 else "",
                "latency_run3": run_latencies[2] if len(run_latencies) > 2 else "",
                "latency_avg": latency_avg,
                "plan": plan if error == "" else "",
                "cardinality": cardinality,
                "error": error
            })

    finally:
        cursor.close()
        conn.close()

    # Overall average
    valid = [r["latency_avg"] for r in results if isinstance(r["latency_avg"], float)]
    overall_avg = sum(valid) / len(valid) if valid else ""

    # Save CSV
    fieldnames = [
        "db_name",
        "query_id",
        "type",
        "latency_run1",
        "latency_run2",
        "latency_run3",
        "latency_avg",
        "plan",
        "cardinality",
        "error"
    ]

    with open(csv_file, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(results)
        writer.writerow({
            "db_name": db_name,
            "query_id": "AVG",
            "latency_avg": overall_avg
        })

    print("\nCSV saved to:")
    print(csv_file)

    if overall_avg != "":
        print(f"Overall Average Latency ({db_name}): {overall_avg:.6f}s")

    return csv_file, overall_avg


# ===============================
# 5. Main
# ===============================
def main():
    for cfg in DB_CONFIGS:
        benchmark_one_db(
            db_name=cfg["db_name"],
            sql_file=sql_file,
            run_times=RUN_TIMES
        )


if __name__ == "__main__":
    main()