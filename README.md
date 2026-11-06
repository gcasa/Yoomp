# Yoomp!

A desktop remake of the tunnel arcade game. Steer an automatically bouncing
ball around the inside of a tiled tunnel and land on solid ground. The six
courses use new layouts and procedural graphics. An original SID-style
chiptune loops during play.

## Build on macOS

With the Xcode command-line tools installed, run:

```sh
make
open Yoomp.app
```

## Build with GNUstep

Install GNUstep Make, Base, GUI, an Objective-C compiler, and a working GNUstep
GUI backend. Source your installation's `GNUstep.sh` if your shell does not
already have its GNUstep environment configured. From a clean source directory:

```sh
make GNUSTEP=1
openapp ./Yoomp.app
```

Use GNU Make (often `gmake` on BSD). The `GNUSTEP=1` switch selects GNUstep
on macOS as well. Build in separate source directories or clean with the same
build mode you used before switching, since both builds produce `Yoomp.app`.

## Play

- **Left / Right** or **A / D** moves one lane per press.
- **Space** or **Return** starts the game, retries a stage, or advances.
- **P** or **Escape** pauses or resumes. Losing window focus pauses play.
- **R** returns to the title and resets the run.

Gold tiles give you a higher bounce. Green tiles slow forward motion briefly.
A missed landing costs one life and resets the score to the start of the stage.
