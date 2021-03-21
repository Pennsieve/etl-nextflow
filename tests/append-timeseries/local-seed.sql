TRUNCATE "1".packages RESTART IDENTITY CASCADE;
TRUNCATE "1".channels RESTART IDENTITY CASCADE;
INSERT INTO "1".packages (
    id, name, type, dataset_id, owner_id, state, import_id, attributes, node_id
)
VALUES(
    1, 'Test TimeSeries Package', 'TimeSeries' , 1, 1, 'UNAVAILABLE', 'dc3600b4-da55-4307-80e4-163920675653', '[{"key": "meta","value": "secrets","dataType": "string","category": "user-defined","fixed": true,"hidden": true}]', 'test-package-node-id'
);
INSERT INTO "1".channels (
    node_id, package_id, name, start, "end", unit, rate, type, "group", last_annotation
)
VALUES
( 'N:channel:channel-0', 1, 'noise',      1505222904575664, 1505223104565664, 'uV', 200.0, 'CONTINUOUS', 'default', 0),
( 'N:channel:channel-1', 1, 'pulse',      1505222904575664, 1505223104565664, 'uV', 200.0, 'CONTINUOUS', 'default', 0),
( 'N:channel:channel-2', 1, 'ramp',       1505222904575664, 1505223104565664, 'uV', 200.0, 'CONTINUOUS', 'default', 0),
( 'N:channel:channel-3', 1, 'sine 1 Hz',  1505222904575664, 1505223104565664, 'uV', 200.0, 'CONTINUOUS', 'default', 0),
( 'N:channel:channel-4', 1, 'sine 15 Hz', 1505222904575664, 1505223104565664, 'uV', 200.0, 'CONTINUOUS', 'default', 0);
