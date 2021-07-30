import std.stdio, std.file, std.algorithm, std.process, std.string, std.conv, std.bitmanip, std.range;

enum INSERT_ADDRESS     = 0x172A0;
enum EVERY_FRAME_HOOK   = 0x9954;
enum ON_DEACTIVATE_HOOK = 0xA7A0;

static immutable uint[] REPLACES =[
  0x17094,  // set_camera
  0x1714C,  // reset_camera
  0x17198,  // push_stage_camera
  0x17200,  // pop_stage_camera
  0x17220,  // set_visibility_stage_effect
];

int main() {
  //very hacky patcher because i'm tired of copy-pasting in brawlbox module editor

  version (Windows) {
    string[] command;
  }
  else {  //linux moment
    string[] command = ["wine"];
  }
  command ~= ["powerpc-gekko-as.exe", "-a32", "-mbig", "-mregnames", "-mgekko", "final_stuff.asm"];

  auto shell = execute(command, null, Config.suppressConsole);

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
      uint chosen = bigEndianToNative!ushort(section1[i+2..i+4][0..2]); //lol wish the compiler could figure out the length without the [0..2]
      if (chosen >= REPLACES.length) continue;

      section1.patchBranch(cast(uint) i, REPLACES[chosen], true);
    }
  }

  {
    //hack in the two relocations i use in my own asm. this code sucks
    //wish this could be smarter but it would take way too much work because of how relocation data works

    enum uint RELOC_SIZE_LOW_BYTE_OFFSET = 0x23557;
    enum uint RELOC_INSERT_OFFSET        = 0x27F00;
    enum uint LAST_PIT_RELOC_OFFSET      = 0x1720C; //this could change if i put more relocations after pop_stage_camera

    moduleBytes.patch(RELOC_SIZE_LOW_BYTE_OFFSET, [0xB0]); //increases by 0x20 bytes

    moduleBytes.insertInPlace(RELOC_INSERT_OFFSET, cast(ubyte[]) [0x01, 0x08, 0x06, 0x06, 0x00, 0x00, 0x03, 0x30, 0x00, 0x04, 0x04, 0x06, 0x00, 0x00, 0x03, 0x30, 0x00, 0x9C, 0x06, 0x06, 0x00, 0x00, 0x03, 0x30, 0x00, 0x04, 0x04, 0x06, 0x00, 0x00, 0x03, 0x30]);

    //look for lis r3, 0 ; addi r3, r3, 0
    auto firstRelocOffset = section1[INSERT_ADDRESS  ..$].countUntil([0x3C, 0x60, 0x00, 0x00, 0x38, 0x63, 0x00, 0x00]) + INSERT_ADDRESS;
    //look for lis r4, 0 ; addi r4, r4, 0
    auto thirdRelocOffset = section1[firstRelocOffset..$].countUntil([0x3C, 0x80, 0x00, 0x00, 0x38, 0x84, 0x00, 0x00]) + firstRelocOffset;

    moduleBytes.patch(RELOC_INSERT_OFFSET,      nativeToBigEndian!ushort(cast(ushort) (firstRelocOffset - LAST_PIT_RELOC_OFFSET)));
    moduleBytes.patch(RELOC_INSERT_OFFSET + 16, nativeToBigEndian!ushort(cast(ushort) (thirdRelocOffset - (firstRelocOffset + 4) ))); // second reloc offset is 4 bytes after the first
  }

  std.file.write("ft_waluigi.rel", moduleBytes);

  return 0;
}

void patch(ubyte[] data, uint address, ubyte[] stuff) {
  data[address..address+stuff.length] = stuff;
}

void patchBranch(ubyte[] data, uint from, uint to, bool link) {
  data.patch(from, nativeToBigEndian!uint(0x48000000 | ((to - from) & 0x03FFFFFF) | link)[]);
}
