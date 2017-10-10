CREATE TABLE reindex_test(time timestamp, temp float, PRIMARY KEY(time, temp));
CREATE UNIQUE INDEX reindex_test_time_unique_idx ON reindex_test(time);

-- create hypertable with three chunks
SELECT create_hypertable('reindex_test', 'time', chunk_time_interval => 2628000000000);

INSERT INTO reindex_test VALUES ('2017-01-20T09:00:01', 17.5),
                                ('2017-01-21T09:00:01', 19.1),
                                ('2017-04-20T09:00:01', 89.5),
                                ('2017-04-21T09:00:01', 17.1),
                                ('2017-06-20T09:00:01', 18.5),
                                ('2017-06-21T09:00:01', 11.0);

SELECT * FROM test.show_columns('reindex_test');
SELECT * FROM test.show_subtables('reindex_test');

-- show reindexing
REINDEX (VERBOSE) TABLE reindex_test;

\set ON_ERROR_STOP 0
-- this one currently doesn't recurse to chunks and instead gives an
-- error
REINDEX (VERBOSE) INDEX reindex_test_time_unique_idx;
\set ON_ERROR_STOP 1

-- show reindexing on a normal table
CREATE TABLE reindex_norm(time timestamp, temp float);
CREATE UNIQUE INDEX reindex_norm_time_unique_idx ON reindex_norm(time);

INSERT INTO reindex_norm VALUES ('2017-01-20T09:00:01', 17.5),
                                ('2017-01-21T09:00:01', 19.1),
                                ('2017-04-20T09:00:01', 89.5),
                                ('2017-04-21T09:00:01', 17.1),
                                ('2017-06-20T09:00:01', 18.5),
                                ('2017-06-21T09:00:01', 11.0);

REINDEX (VERBOSE) TABLE reindex_norm;
REINDEX (VERBOSE) INDEX reindex_norm_time_unique_idx;

SELECT * FROM test.show_constraintsp('_timescaledb_internal.%');
SELECT * FROM reindex_norm;

SELECT * FROM test.show_indexes('_timescaledb_internal._hyper_1_1_chunk');

SELECT indexrelid AS original_indexoid FROM pg_index WHERE indexrelid = '_timescaledb_internal._hyper_1_1_chunk_reindex_test_time_unique_idx'::regclass
\gset

SELECT reindex('reindex_test', verbose=>true);

SELECT indexrelid AS reindex_indexoid FROM pg_index WHERE indexrelid = '_timescaledb_internal._hyper_1_1_chunk_reindex_test_time_unique_idx'::regclass
\gset

SELECT :original_indexoid = :reindex_indexoid;

SELECT reindex('reindex_test', verbose=>true, recreate=>true);

SELECT indexrelid AS remake_indexoid FROM pg_index WHERE indexrelid = '_timescaledb_internal._hyper_1_1_chunk_reindex_test_time_unique_idx'::regclass
\gset

SELECT :original_indexoid = :remake_indexoid;

--reindex only a particular index
SELECT reindex('reindex_test_pkey', verbose=>true, recreate=>true);

--from_time
SELECT reindex('reindex_test_pkey', time_column=>'time', from_time=>TIMESTAMP '2017-06-20T12:00:00', verbose=>true, recreate=>true);

--to_time (note awkwardness with having to declare a NULL from_time)
SELECT reindex('reindex_test_pkey', 
    time_column=>'time', from_time=>NULL::timestamp, to_time=>TIMESTAMP '2017-02-18 20:00:00',
    verbose=>true, recreate=>true);

--both from and to time
SELECT reindex('reindex_test_pkey', 
    time_column=>'time', from_time=>'2017-01-19 10:00:00'::timestamp, to_time=>TIMESTAMP '2017-02-18 20:00:00', 
    verbose=>true, recreate=>true);

--empty set
SELECT reindex('reindex_test_pkey', 
    time_column=>'time', from_time=>'2017-01-19 06:00:00'::timestamp, to_time=>TIMESTAMP '2017-02-18 15:00:00', 
    verbose=>true, recreate=>true);

SELECT * FROM test.show_indexes('_timescaledb_internal._hyper_1_1_chunk');
