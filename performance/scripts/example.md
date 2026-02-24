

cbc-pillowfight -U "couchbase://${CB_HOST}/${CB_BUCKET}" -u "${CB_USER}" -P "${CB_PASSWORD}" --batch-size 1 --num-cycles 6000 --num-items 100000 --num-threads 1 --min-size 1024 --max-size 1024 --set-pct 10 --timings --timings 2> /tmp/timings.txt
