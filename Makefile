demo:
	docker compose up --build -d

reset:
	docker compose down -v
	docker compose up --build -d

logs:
	docker compose logs -f

check:
	docker compose exec clickhouse clickhouse-client \
	--user default --password clickhouse \
	--query "SHOW TABLES"

rollups:
	docker compose exec clickhouse clickhouse-client \
	--user default --password clickhouse \
	--query "SELECT service, round(quantileMerge(0.95)(p95_latency_state),2) AS p95, round(quantileMerge(0.99)(p99_latency_state),2) AS p99 FROM latency_rollup_1m GROUP BY service ORDER BY p99 DESC"