TRUNCATE "1".packages CASCADE;
INSERT INTO "1".packages (id, name, type, dataset_id, owner_id, state, import_id, attributes, node_id) VALUES(1, 'Test TimeSeries Package', 'TimeSeries' , 1, 1, 'UNAVAILABLE', 'dc3600b4-da55-4307-80e4-163920675653', '[{"key": "meta","value": "secrets","dataType": "string","category": "user-defined","fixed": true,"hidden": true}]', 'test-package-node-id');
