TRUNCATE "1".packages CASCADE;

INSERT INTO "1".packages (id, name, type, dataset_id, owner_id, state, import_id, attributes, node_id) VALUES (1, 'Test TimeSeries Package', 'TimeSeries' , 1, 1, 'READY', 'dc3600b4-da55-4307-80e4-163920675653', '[{"key": "meta","value": "secrets","dataType": "string","category": "user-defined","fixed": true,"hidden": true}]', 'test-timeseries-node-id');
INSERT INTO "1".packages (id, name, type, dataset_id, owner_id, state, import_id, attributes, node_id) VALUES (2, 'Test NWB Package', 'HDF5' , 1, 1, 'READY', '3c3600b4-da55-4307-80e4-163920675653', '[{"key": "meta","value": "secrets","dataType": "string","category": "user-defined","fixed": true,"hidden": true}]', 'test-nwb-node-id');

INSERT INTO "1".channels (node_id, package_id, name, "start", "end", unit, rate, "type", "group", "last_annotation") VALUES ('test-channel-node-id-1', 1, 'LG19', 946684800000000, 946685000035214, 'uV', 499.906982421875, 'CONTINUOUS', 'default', 0);
INSERT INTO "1".channels (node_id, package_id, name, "start", "end", unit, rate, "type", "group", "last_annotation") VALUES ('test-channel-node-id-2', 1, 'LG30', 946684800000000, 946685000035214, 'uV', 499.906982421875, 'CONTINUOUS', 'default', 0);
INSERT INTO "1".channels (node_id, package_id, name, "start", "end", unit, rate, "type", "group", "last_annotation") VALUES ('test-channel-node-id-3', 1, 'LG21', 946684800000000, 946685000035214, 'uV', 499.906982421875, 'CONTINUOUS', 'default', 0);
INSERT INTO "1".channels (node_id, package_id, name, "start", "end", unit, rate, "type", "group", "last_annotation") VALUES ('test-channel-node-id-4', 1, 'LG2',  946684800000000, 946685000035214, 'uV', 499.906982421875, 'CONTINUOUS', 'default', 0);

INSERT INTO timeseries.ranges (channel, rate, range, location, follows_gap) VALUES ('test-channel-node-id-1', 499.906982421875, '[946684800000000,946685000035214)', 'export-timeseries/data/test-channel-node-id-1_1.bfts.gz', FALSE);
INSERT INTO timeseries.ranges (channel, rate, range, location, follows_gap) VALUES ('test-channel-node-id-2', 499.906982421875, '[946684800000000,946685000035214)', 'export-timeseries/data/test-channel-node-id-2_1.bfts.gz', FALSE);
INSERT INTO timeseries.ranges (channel, rate, range, location, follows_gap) VALUES ('test-channel-node-id-3', 499.906982421875, '[946684800000000,946685000035214)', 'export-timeseries/data/test-channel-node-id-3_1.bfts.gz', FALSE);
INSERT INTO timeseries.ranges (channel, rate, range, location, follows_gap) VALUES ('test-channel-node-id-4', 499.906982421875, '[946684800000000,946685000035214)', 'export-timeseries/data/test-channel-node-id-4_1.bfts.gz', FALSE);
