#!/bin/bash
sleep 15
kafka-topics 
--create 
--topic app_logs 
--bootstrap-server kafka:9092 
--partitions 3 
--replication-factor 1
