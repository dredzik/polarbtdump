# polarbtdump

#### Bluetooth LE data dumper for Polar M400 (and other) watches.

This is a simple tool that runs a bluetooth le service for downloading data from 
Polar M400 watches. It can probably be used against other Polar watches that
can be synced with the Polar Flow app on the iPhone, but I haven't tested it.

#### Compile

```
cd polarbtdump
xcodebuild
```

#### Run

`./build/Release/polarbtdump`

#### Data

All data will be dumped into `${user.home}/.polar/backup/bt/` directory. Please
note that this data is still in polar format (Google Procol Buffers encoded).
