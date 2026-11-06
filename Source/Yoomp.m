#import <AppKit/AppKit.h>

#include <math.h>
#include "Game.h"

#define TUNNEL_RADIUS 2.3
#define CAMERA_DEPTH 3.4
#define ANGLE_PER_LANE (6.283185307179586 / GAME_LANES)

@interface YoompView : NSView
{
  Game game;
  NSTimer *timer;
  NSTimeInterval lastTick;
  NSSound *music;
}
- (void) tick: (NSTimer *)sender;
- (void) pauseGame: (id)sender;
- (void) restartGame: (id)sender;
@end

static NSPoint
project (NSPoint center, double focal, double lane, double depth)
{
  double angle;
  double radius;

  angle = lane * ANGLE_PER_LANE;
  radius = focal * TUNNEL_RADIUS / depth;
  return NSMakePoint (center.x + sin (angle) * radius,
                      center.y - cos (angle) * radius);
}

static NSColor *
tile_color (Tile tile, unsigned int stage, int parity, double light)
{
  double hue;
  double saturation;

  hue = fmod (0.54 + stage * 0.137 + parity * 0.065, 1.0);
  saturation = 0.72;
  switch (tile)
    {
    case TILE_BOOST:
      hue = 0.11;
      break;
    case TILE_SLOW:
      hue = 0.32;
      break;
    case TILE_FINISH:
      saturation = 0.08;
      break;
    case TILE_NORMAL:
    case TILE_HOLE:
      break;
    }
  return [NSColor colorWithCalibratedHue: hue saturation: saturation
                  brightness: light alpha: 1.0];
}

static void
draw_text (NSString *text, NSFont *font, NSColor *color, NSPoint point,
           BOOL centered)
{
  NSDictionary *attributes;

  attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                  font, NSFontAttributeName, color,
                  NSForegroundColorAttributeName, nil];
  if (centered)
    point.x -= [text sizeWithAttributes: attributes].width / 2.0;
  [text drawAtPoint: point withAttributes: attributes];
}

@implementation YoompView

- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self)
    {
      NSString *track;

      game_reset (&game);
      track = [[NSBundle mainBundle] pathForResource: @"Tunnel" ofType: @"wav"];
      if (track)
        {
          music = [[NSSound alloc] initWithContentsOfFile: track byReference: YES];
          [music setLoops: YES];
        }
    }
  return self;
}

- (BOOL) acceptsFirstResponder
{
  return YES;
}

- (BOOL) isOpaque
{
  return YES;
}

- (void) viewDidMoveToWindow
{
  [super viewDidMoveToWindow];
  [timer invalidate];
  timer = nil;
  if ([self window])
    {
      lastTick = [NSDate timeIntervalSinceReferenceDate];
      timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60.0
                        target: self selector: @selector (tick:)
                        userInfo: nil repeats: YES];
      [[NSNotificationCenter defaultCenter] addObserver: self
        selector: @selector (lostFocus:)
        name: NSWindowDidResignKeyNotification object: [self window]];
    }
  else
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [timer invalidate];
  [music stop];
  [music release];
  [super dealloc];
}

- (void) lostFocus: (NSNotification *)notification
{
  (void) notification;
  if (game.status == GAME_RUNNING)
    [self pauseGame: nil];
}

- (void) updateMusicFrom: (GameStatus)previousStatus
{
  if (game.status == previousStatus)
    return;

  if (game.status == GAME_RUNNING)
    {
      if (![music resume])
        [music play];
    }
  else if (game.status == GAME_PAUSED)
    [music pause];
  else
    [music stop];
}

- (void) tick: (NSTimer *)sender
{
  NSTimeInterval now;

  (void) sender;
  now = [NSDate timeIntervalSinceReferenceDate];
  if (game.status == GAME_RUNNING)
    {
      game_step (&game, fmin (now - lastTick, 0.05));
      [self updateMusicFrom: GAME_RUNNING];
      [self setNeedsDisplay: YES];
    }
  lastTick = now;
}

- (void) pauseGame: (id)sender
{
  GameStatus previousStatus;

  (void) sender;
  previousStatus = game.status;
  game_pause (&game);
  [self updateMusicFrom: previousStatus];
  [self setNeedsDisplay: YES];
}

- (void) restartGame: (id)sender
{
  (void) sender;
  game_reset (&game);
  [music stop];
  [self setNeedsDisplay: YES];
}

- (void) keyDown: (NSEvent *)event
{
  NSString *characters;
  unichar key;
  GameStatus previousStatus;

  characters = [[event charactersIgnoringModifiers] lowercaseString];
  if ([characters length] != 1)
    {
      [super keyDown: event];
      return;
    }

  key = [characters characterAtIndex: 0];
  if ([event isARepeat])
    return;

  switch (key)
    {
    case NSLeftArrowFunctionKey:
    case 'a':
      game_turn (&game, -1);
      break;
    case NSRightArrowFunctionKey:
    case 'd':
      game_turn (&game, 1);
      break;
    case ' ':
    case '\r':
      previousStatus = game.status;
      game_action (&game);
      [self updateMusicFrom: previousStatus];
      break;
    case 'p':
    case '\033':
      [self pauseGame: nil];
      return;
    case 'r':
      [self restartGame: nil];
      return;
    default:
      [super keyDown: event];
      return;
    }
  [self setNeedsDisplay: YES];
}

- (void) drawTunnelAt: (NSPoint)center focal: (double)focal
{
  int row;
  int lane;
  int firstRow;
  int lastRow;
  double camera;

  camera = game.position - CAMERA_DEPTH;
  firstRow = (int) floor (camera + 0.35);
  lastRow = (int) floor (game.position) + 28;
  if (lastRow > game_length (game.stage) + 1)
    lastRow = game_length (game.stage) + 1;

  for (row = lastRow; row >= firstRow; --row)
    {
      double near;
      double far;
      double light;

      near = fmax (0.35, row - camera);
      far = row + 1.0 - camera;
      light = 0.14 + 0.76 / (1.0 + far * 0.17);
      for (lane = 0; lane < GAME_LANES; ++lane)
        {
          Tile tile;
          NSPoint points[4];
          NSBezierPath *path;
          double angle;
          int parity;

          tile = game_tile (game.stage, row, lane);
          if (tile == TILE_HOLE)
            continue;

          angle = lane - game.lane - 0.5;
          parity = (row + lane) & 1;
          points[0] = project (center, focal, angle, near);
          points[1] = project (center, focal, angle + 1.0, near);
          points[2] = project (center, focal, angle + 1.0, far);
          points[3] = project (center, focal, angle, far);

          path = [NSBezierPath bezierPath];
          [path appendBezierPathWithPoints: points count: 4];
          [path closePath];
          [tile_color (tile, game.stage, parity, light * (parity ? 0.78 : 1.0))
            set];
          [path fill];
          [[NSColor colorWithCalibratedWhite: 0.03 alpha: 0.55] set];
          [path setLineWidth: 1.0];
          [path stroke];
        }
    }
}

- (void) drawBallAt: (NSPoint)center focal: (double)focal
{
  double floorY;
  double ballY;
  double radius;
  NSRect ball;
  NSRect shine;

  floorY = center.y - focal * TUNNEL_RADIUS * cos (ANGLE_PER_LANE / 2.0)
           / CAMERA_DEPTH;
  radius = focal * 0.16 / CAMERA_DEPTH;
  ballY = floorY + radius + focal * game.height / CAMERA_DEPTH;
  if (game.status == GAME_CRASHED || game.status == GAME_OVER)
    return;

  [[NSColor colorWithCalibratedWhite: 0.0 alpha: 0.45] set];
  if (game_tile (game.stage, (int) floor (game.position),
                 game.lane) != TILE_HOLE)
    [NSBezierPath fillRect: NSMakeRect (center.x - radius, floorY - 1.5,
                                      radius * 2.0, 3.0)];

  ball = NSMakeRect (center.x - radius, ballY - radius,
                     radius * 2.0, radius * 2.0);
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.53 blue: 0.18 alpha: 1.0]
    set];
  [[NSBezierPath bezierPathWithOvalInRect: ball] fill];
  shine = NSMakeRect (center.x - radius * 0.55, ballY + radius * 0.1,
                      radius * 0.65, radius * 0.55);
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.9 blue: 0.66 alpha: 1.0]
    set];
  [[NSBezierPath bezierPathWithOvalInRect: shine] fill];
}

- (void) drawOverlayAt: (NSPoint)center width: (double)width
{
  NSString *title;
  NSString *detail;
  NSColor *white;

  title = nil;
  detail = nil;
  switch (game.status)
    {
    case GAME_READY:
      title = @"Yoomp!";
      detail = @"Space to start. Steer with Left / Right or A / D.";
      break;
    case GAME_PAUSED:
      title = @"Paused";
      detail = @"Space or P to resume";
      break;
    case GAME_CRASHED:
      title = @"Mind the gap";
      detail = @"Space to retry the stage";
      break;
    case GAME_OVER:
      title = @"Game over";
      detail = @"Space to start a new run";
      break;
    case GAME_STAGE_CLEAR:
      title = @"Stage clear";
      detail = @"Space for the next stage";
      break;
    case GAME_WON:
      title = @"Run complete";
      detail = @"Space to play again";
      break;
    case GAME_RUNNING:
      return;
    }

  white = [NSColor whiteColor];
  [[NSColor colorWithCalibratedWhite: 0.025 alpha: 0.91] set];
  NSRectFillUsingOperation (NSMakeRect (0.0, center.y - 52.0, width, 105.0),
                            NSCompositeSourceOver);
  draw_text (title, [NSFont boldSystemFontOfSize: 36.0], white,
             NSMakePoint (center.x, center.y - 2.0), YES);
  draw_text (detail, [NSFont systemFontOfSize: 15.0], white,
             NSMakePoint (center.x, center.y - 30.0), YES);
}

- (void) drawRect: (NSRect)dirtyRect
{
  NSRect bounds;
  NSPoint center;
  NSColor *white;
  NSString *hud;
  double focal;
  double width;
  double height;
  double progress;

  bounds = [self bounds];
  width = NSWidth (bounds);
  height = NSHeight (bounds);
  center = NSMakePoint (width / 2.0, height / 2.0);
  focal = fmin (width, height) * 0.49;
  [[NSColor colorWithCalibratedRed: 0.035 green: 0.04 blue: 0.08 alpha: 1.0]
    set];
  NSRectFill (dirtyRect);
  [self drawTunnelAt: center focal: focal];
  [self drawBallAt: center focal: focal];

  [[NSColor colorWithCalibratedWhite: 0.04 alpha: 0.9] set];
  NSRectFillUsingOperation (NSMakeRect (0.0, height - 48.0, width, 48.0),
                            NSCompositeSourceOver);
  white = [NSColor whiteColor];
  hud = [NSString stringWithFormat: @"Stage %u / %d     Score %u     Lives %u",
                  game.stage + 1, GAME_STAGES, game.score, game.lives];
  draw_text (hud, [NSFont boldSystemFontOfSize: 14.0], white,
             NSMakePoint (center.x, height - 29.0), YES);
  progress = fmin (1.0, game.position / game_length (game.stage));
  [[NSColor colorWithCalibratedWhite: 0.23 alpha: 1.0] set];
  NSRectFill (NSMakeRect (0.0, height - 48.0, width, 3.0));
  [[NSColor colorWithCalibratedRed: 1.0 green: 0.61 blue: 0.24 alpha: 1.0]
    set];
  NSRectFill (NSMakeRect (0.0, height - 48.0, width * progress, 3.0));

  [self drawOverlayAt: center width: width];
}

@end

@interface YoompController : NSObject <NSApplicationDelegate>
{
  NSWindow *window;
}
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)app;
@end

static void
add_menu_item (NSMenu *menu, NSString *title, SEL action, NSString *key,
               id target)
{
  NSMenuItem *item;

  item = [menu addItemWithTitle: title action: action keyEquivalent: key];
  [item setTarget: target];
}

@implementation YoompController

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSMenu *bar;
  NSMenu *menu;
  NSMenuItem *root;
  YoompView *view;

  (void) notification;
  window = [[NSWindow alloc]
            initWithContentRect: NSMakeRect (0.0, 0.0, 800.0, 600.0)
                      styleMask: NSTitledWindowMask | NSClosableWindowMask
                                 | NSMiniaturizableWindowMask
                                 | NSResizableWindowMask
                        backing: NSBackingStoreBuffered defer: NO];
  [window setReleasedWhenClosed: NO];
  [window setTitle: @"Yoomp!"];
  [window setContentMinSize: NSMakeSize (420.0, 300.0)];
  view = [[YoompView alloc] initWithFrame: [[window contentView] bounds]];
  [view setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [window setContentView: view];

  bar = [[NSMenu alloc] initWithTitle: @""];
  root = [bar addItemWithTitle: @"Yoomp!" action: NULL keyEquivalent: @""];
  menu = [[NSMenu alloc] initWithTitle: @"Yoomp!"];
  add_menu_item (menu, @"Quit Yoomp!", @selector (terminate:), @"q", NSApp);
  [bar setSubmenu: menu forItem: root];
  [menu release];

  root = [bar addItemWithTitle: @"Game" action: NULL keyEquivalent: @""];
  menu = [[NSMenu alloc] initWithTitle: @"Game"];
  add_menu_item (menu, @"Pause / Resume", @selector (pauseGame:), @"p", view);
  add_menu_item (menu, @"Restart", @selector (restartGame:), @"r", view);
  [bar setSubmenu: menu forItem: root];
  [menu release];
  [NSApp setMainMenu: bar];
  [bar release];

  [window center];
  [window makeFirstResponder: view];
  [window makeKeyAndOrderFront: nil];
  [view release];
  [NSApp activateIgnoringOtherApps: YES];
}

- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)app
{
  (void) app;
  return YES;
}

- (void) dealloc
{
  [window setContentView: nil];
  [window release];
  [super dealloc];
}

@end

int
main (int argc, const char *argv[])
{
  NSAutoreleasePool *pool;
  YoompController *controller;

  (void) argc;
  (void) argv;
  pool = [[NSAutoreleasePool alloc] init];
  [NSApplication sharedApplication];
#ifndef GNUSTEP
  [NSApp setActivationPolicy: NSApplicationActivationPolicyRegular];
#endif
  controller = [[YoompController alloc] init];
  [NSApp setDelegate: controller];
  [NSApp run];
  [NSApp setDelegate: nil];
  [controller release];
  [pool drain];
  return 0;
}
