import std.stdio, std.file, std.algorithm, std.process, std.string, std.conv, std.bitmanip, std.range;

enum INSERT_ADDRESS     = 0x16CE0;
enum EVERY_FRAME_HOOK   = 0x9954;
enum ON_DEACTIVATE_HOOK = 0xA7A0;

static immutable uint[] REPLACES =[
  0x17094,  // set_camera
  0x1714C,  // reset_camera
  0x17198,  // push_stage_camera
  0x17200,  // pop_stage_camera
];

int main() {
  //very hacky patcher because i'm tired of copy-pasting in brawlbox module editor

  auto shell = execute(["wine", "powerpc-gekko-as.exe", "-a32", "-mbig", "-mregnames", "-mgekko", "final_stuff.asm"], null, Config.suppressConsole);

  if (!exists("a.out")) {
    stderr.writeln("woops");
    return 1;
  }

  scope(exit) std.file.remove("a.out");

  auto assembled = cast(ubyte[]) std.file.read("a.out");
  assembled = assembled[52..assembled.countUntil([0x00, 0x2E, 0x73, 0x79, 0x6D, 0x74, 0x61, 0x62])];

  uint everyFrameOffset   = INSERT_ADDRESS;
  uint onDeactivateOffset = INSERT_ADDRESS + cast(uint) assembled.countUntil(nativeToBigEndian!uint(0xFADEF00D)[]) + 4;

  auto moduleBytes = cast(ubyte[]) std.file.read("ft_waluigi_vanilla.rel");
  auto section1Offset = moduleBytes.countUntil([0x3C, 0xC0, 0x00, 0x00, 0x80, 0x06, 0x00, 0x00, 0x90, 0x05, 0x00, 0x00, 0x90, 0x85, 0x00, 0x04]);
  auto section1 = moduleBytes[section1Offset..$];

  section1.patchBranch(EVERY_FRAME_HOOK,   everyFrameOffset,   true);
  section1.patchBranch(ON_DEACTIVATE_HOOK, onDeactivateOffset, false);

  section1.patch(INSERT_ADDRESS, assembled);

  foreach (i; iota(0, section1.length, 4)) {
    if (section1[i..i+2] == [0xC0, 0xDE]) {
      uint chosen = bigEndianToNative!ushort(section1[i+2..i+4][0..2]); //lol wish it could figure out the length without this
      if (chosen >= REPLACES.length) continue;

      section1.patchBranch(cast(uint) i, REPLACES[chosen], true);
    }
  }

  std.file.write("ft_waluigi.rel", moduleBytes);

  return 0;
}

void patch(ubyte[] data, uint address, ubyte[] stuff) {
  data[address..address+stuff.length] = stuff;
}

void patchBranch(ubyte[] data, uint from, uint to, bool link) {
  data.patch(from, nativeToBigEndian!uint(0x48000000 | (to - from) | link)[]);
}


/*
  3C C0 00 00 80 06 00 00 90 05 00 00 90 85 00 04
*/