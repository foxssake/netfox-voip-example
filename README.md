# netfox VoIP example

An **experimental** sample of VoIP with [Godot] and [netfox].

## Overview

This sample implements a simple form of VoIP.

Voice data is captured from the microphone, quantized to 8 bits per sample, and
then broadcasted as-is to other peers. Voice data is played back as it arrives.

## Running

To run the example, open it with Godot 4.x and click Run the Project, or press
F5.

## Usage

To setup VoIP in your own project, take the following steps.

### Audio setup

The sample code relies on an audio bus configured specifically for recording
sound. In the project, this bus is called *Record*, but can be changed.

The bus *must* have a Capture effect configured.

Mute the bus, so it is captured but not played back.

### Adding code

Copy the VoIP-related scripts from the example to your project:

* `scripts/voice-source.gd`
* `scripts/voice-sink.gd`
* `scripts/voip-sink.gd`

### Transmitting voice

Add a `VoiceSource` node to your scene. Make sure to set the `bus_name` to the
bus you've configured in the *Audio setup* step earlier. The node will emit
`on_data` events with audio buffers.

To push voice over the network, add a `VoipSink` node. Make sure to set its
multiplayer authority ( from code ).

Sinks by themselves do nothing, they expect data to be pushed to them from
other nodes. To do so, connect the `VoiceSource` node's `on_data` signal to the
`VoipSink`'s `push_data` method.

## Limitations

### Audio compression

Currently, no audio compression is implemented. This means ~11kb/s upload for
each player, and ~11kb/s download for each player *per player* and ~11kb/s
upload for the server *per player*. 

To take an example with 4 players, the server will have a 44kb/s upload and 33
kb/s download, while the other players will have a 33kb/s download and 11kb/s
upload ( since nobody downloads their own voice ).

The builtin [PackedByteArray.compress] implements some compression algorithms,
but they are lossless, general, and don't work well for voice. During
development, they actually increased size.

Integrating the [Opus codec] would be a great fit to compress audio data before
sending it through the network. There's another project called
[libopus-gdnative-voip-demo] that does exactly this, but the Opus integration
behind it is Godot 3.x only.

### Reliability

In theory, the sample should work fine, as it uses RPCs like any other game
would.

In practice, I've encountered cases where voice was one-way only.

## Support

This is an **experimental** sample to see if Godot's capable of VoIP.

This also means that currently there's no plans to build this sample further,
as proper maintenance would take too much bandwidth for now. However, we
encourage you to take a look, see if you can reuse or learn something, fork the
repo and/or contribute.

Things that *are* supported and *will be* fixed if reported:

* Documentation issues
  * example: Typo in documentation comment
  * example: Readme is not up to date
* Implementation bugs
  * Flaws/unexpected behaviour in project's existing scope
  * Case-by-case basis, smaller fixes are OK, large overhauls are not planned

## FAQ

### Is netfox required?

Yes and no.

For the example code, it is needed for events and its noray integration.

If you want to use VoIP in your own project, it is not necessary.

However, the example itself uses netfox, hence the project name.

### Will it support X?

New features are currently not planned. However, PR's are always welcome!

## Issues

If you've encountered an issue that is covered by the [Support](#support), feel
free to open an [issue]!

## License

This project is under the [MIT License].

[Godot]: https://godotengine.org/
[netfox]: https://github.com/foxssake/netfox
[PackedByteArray.compress]: https://docs.godotengine.org/en/stable/classes/class_packedbytearray.html#class-packedbytearray-method-compress
[Opus codec]: https://opus-codec.org/
[libopus-gdnative-voip-demo]: https://github.com/Godot-Opus/libopus-gdnative-voip-demo
[issue]: https://github.com/foxssake/netfox-voip-example/issues
[MIT License]: LICENSE
