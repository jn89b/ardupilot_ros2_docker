## `/ap/state/correction` JSONL Record Format

Each correction record is written as one line of JSON:

```json
{
  "topic": "/ap/state/correction",
  "receipt_time_utc": "2026-07-06T18:40:59.650675+00:00",
  "receipt_unix_ns": 1783363259650689444,
  "receipt_ros_ns": 1783363259650694404,
  "data": {
    "values": [
      -0.14014184474945068,
      -0.07086879014968872,
      -0.0199776291847229,
      0.13027799129486084,
      -0.08643949031829834,
      0.17303554713726044
    ]
  }
}
```

### Field meanings

| JSON field         | Meaning                                                                              |
| ------------------ | ------------------------------------------------------------------------------------ |
| `topic`            | ROS 2 topic that produced the record.                                                |
| `receipt_time_utc` | Wall-clock UTC time when the logger received the ROS message.                        |
| `receipt_unix_ns`  | Wall-clock receipt time in Unix nanoseconds. Useful for offline timestamp alignment. |
| `receipt_ros_ns`   | ROS clock time in nanoseconds when the logger received the message.                  |
| `data.values`      | Six-element correction vector produced by the RNN.                                   |

### Correction vector mapping

The correction vector is ordered as:

```text
data.values[0] = d_lat
data.values[1] = d_lon
data.values[2] = d_alt
data.values[3] = d_rot_x
data.values[4] = d_rot_y
data.values[5] = d_rot_z
```

For the example record:

```text
d_lat   = -0.14014184474945068
d_lon   = -0.07086879014968872
d_alt   = -0.0199776291847229
d_rot_x =  0.13027799129486084
d_rot_y = -0.08643949031829834
d_rot_z =  0.17303554713726044
```

The exact units depend on the target values and normalization used during model training. For example, `d_lat` and `d_lon` may be degrees, radians, meters in a local frame, or normalized values. Do not apply these directly to an EKF until the inference node applies the same output scaling or inverse normalization used during training.
