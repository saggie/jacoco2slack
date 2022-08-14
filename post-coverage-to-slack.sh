#!/bin/bash
set -Ceuox pipefail

# 第一引数に Slack の Webhook URL を指定
SLACK_URL="$1"

# 中間処理用の CSV ファイル
CSVFILE="temp.csv" && rm -f $CSVFILE

# 対象のパッケージのリスト
packages=("list" "utilities" "app")

# 指定したパッケージのカバレッジ数 (C0) を返す関数
# - 入力: パッケージ名
# - 出力: "パッケージ名,テストでカバーされた命令行数,全命令行数"
get_coverage () {
    local reportfile="build/reports/jacoco/test/jacocoTestReport.csv"
    if [ -f "$1/$reportfile" ]; then
        echo "$1,"`awk -F ',' '{ covered += $5; instructions += $4 + $5 } END { print covered "," instructions }' "$1/$reportfile"`
    else
        # テストが1件もなかったときはレポートファイルが出力されないため、こちらの分岐に入る。
        # ゼロ除算回避のため、「全命令行数」にゼロではない数字 (0.001) を入れている。
        echo "$1,0,0.001"
    fi
}

# 各パッケージのカバレッジ数を取得し、中間 CSV ファイルに出力
for each_package in "${packages[@]}"; do
    get_coverage "$each_package" >> $CSVFILE
done

# 全パッケージのカバレッジ数を計算し、中間 CSV ファイルに出力
total_covered=`awk -F ',' '{ it += $2 } END { print it }' $CSVFILE`
total_instructions=`awk -F ',' '{ it += $3 } END { print it }' $CSVFILE`
echo "TOTAL,$total_covered,$total_instructions" >> $CSVFILE

# 出力用に結果を整形する
packages+=("TOTAL")
results=()
for each_package in "${packages[@]}"; do
    each_result=`grep "$each_package," $CSVFILE | awk -F ',' '{ printf "%-10s: %3.2f %% (%d / %d)", $1, $2 / $3 * 100, $2, $3 }'`
    results+=("$each_result")
done

# Slack に投稿する
curl "$SLACK_URL" \
  --header 'Content-type: application/json' \
  --data "{\"text\":\"jacoco2slackプロジェクトのC0カバレッジです:
\`\`\`
`printf '%s\n' "${results[@]}"`
\`\`\`\"}"
