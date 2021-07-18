# @ 0x16CE0

every_frame:
  every_frame_start:
    # set up stack / preserve variables
    stwu sp, -52(sp)
    mflr r0
    stw r0, 56(sp)
    stw r3, 8(sp)
    stw r4, 12(sp)
    stw r5, 16(sp)
    # sp+20, for 12 bytes, is a Vec3 used to change Waluigi's position

    # grab our "mailbox" variable, LA-Basic[74] (1000004A), using the getInt function
    bl get_mailbox

    cmpwi r3, 1  # if message is 1,
    beq- enter_final_smash
    cmpwi r3, 2  # if message is 2,
    beq- exit_final_smash
    cmpwi r3, 3  # if message is 3,
    beq- finish_final_smash
    b every_frame_end

  enter_final_smash:
    # freeze pause camera
    li r5, 1
    bl set_camera_freeze

    # hide stage layer
    li r5, 0
    # bl set_layer_disp

    # get camera instance pointer
    lwz r3, -0x41A8(r13)

    # disable zooming (fixes training mode pause)
    # call setDisableZoomStart/[CameraController]/(cm_camera_controller.o)
    lis r12, 0x8009
    ori r12, r12, 0xD250
    mtctr r12
    bctrl

    lwz r3, 0x60(r31)
    li r4, 10
    .int 0xC0DE0000 # hook that will be replaced with call to set_camera in the module

    .int 0xC0DE0002 # hook that will be replaced with call to push_stage_camera in the module

    li r3, 0
    .int 0xC0DE0004 # hook that will be replaced with call to set_visibility_stage_effect in the module


    # load the vector (0.0, 3000.0, 0.0) onto the stack
    addi r4, sp, 20
    li r3, 0
    stw r3, 0(r4)
    stw r3, 8(r4)
    lis r3, 0x453b
    ori r3, r3, 0x8000
    stw r3, 4(r4)

    mr r3, r31
    lwz r3, 0x60(r3)
    lwz r3, 0x18(r3)

    # call setPos/[soPostureModuleSimple]/(so_posture_module_impl.o)
    lis r12, 0x8073
    subi r12, r12, 0x1768
    mtctr r12
    bctrl

    # load new mailbox value (4 = in final smash)
    li r4, 4
    b set_var

  exit_final_smash:
    # unfreeze pause camera
    li r5, 0
    bl set_camera_freeze

    li r3, 1
    .int 0xC0DE0004 # hook that will be replaced with call to set_visibility_stage_effect in the module

    .int 0xC0DE0003 # hook that will be replaced with call to pop_stage_camera in the module

    .int 0xC0DE0001 # hook that will be replaced with call to reset_camera in the module

    # unhide stage layer
    li r5, 1
    # bl set_layer_disp

    # get camera instance pointer
    lwz r3, -0x41A8(r13)

    # reenable zooming (fixes training mode pause)
    # call setDisableZoomEnd/[CameraController]/(cm_camera_controller.o)
    lis r12, 0x8009
    ori r12, r12, 0xD2B0
    mtctr r12
    bctrl

    # load new mailbox value (0 = not in final smash)
    li r4, 0
    b set_var

  finish_final_smash:
    # clear flag that freezes stage lighting
    # TODO: move this to being done in a phase when the final smash state is finally exited
    # (e.g. when the final smash lighting fades out)
    lis r3, 0x805A
    lwz r3, -0x80(r3)
    lbz r0, 0x465(r3)
    rlwimi  r0, r31, 3, 28, 28
    stb r0, 0x465(r3)

    li r4, 0
    b set_var

  set_var:
    # set our mailbox variable by calling setInt (807ACA00)
    # r4 contains its new value
    bl set_mailbox

  every_frame_end:
    # restore variables
    lwz r3, 8(sp)
    lwz r4, 12(sp)
    lwz r5, 16(sp)
    lwz r0, 56(sp)
    mtlr r0
    lwz sp, 0(sp)

    # restore old code
    li r0, 0

    blr

.int 0xFADEF00D

on_deactivate: # called on match end - needed to clean up the camera freeze!
  on_deactivate_start:
    # set up stack / preserve variables
    stwu sp, -16(sp)
    mflr r0
    stw r0, 20(sp)
    stw r3, 8(sp)
    stw r4, 12(sp)

    bl get_mailbox

    # only need to clean up if in the final smash
    cmpwi r3, 4
    bne+ on_deactivate_end

    li r3, 1
    .int 0xC0DE0004 # hook that will be replaced with call to set_visibility_stage_effect in the module

    .int 0xC0DE0003 # hook that will be replaced with call to pop_stage_camera in the module

    .int 0xC0DE0001 # hook that will be replaced with call to reset_camera in the module

    # undo the camera freeze.
    # setting and unsetting the camera freeze seems to actually work like a stack.
    # for every time you call this function with r4 = 1, you need to call it as many times
    # with r4 = 0. so hopefully it was called with 1 only once!!
    li r5, 0
    bl set_camera_freeze

    # reenable all disabled layers
    li r5, 1
    # bl set_layer_disp

    # get camera instance pointer
    lwz r3, -0x41A8(r13)

    # reenable zooming (fixes training mode pause)
    # call setDisableZoomEnd/[CameraController]/(cm_camera_controller.o)
    lis r12, 0x8009
    ori r12, r12, 0xD2B0
    mtctr r12
    bctrl

    # clear flag that freezes stage lighting
    # we're basically undoing a set on this flag done by reset_camera
    lis r3, 0x805A
    lwz r3, -0x80(r3)
    lbz r0, 0x465(r3)
    rlwimi  r0, r31, 3, 28, 28
    stb r0, 0x465(r3)

    # set our mailbox variable to 0  so we don't do this a second time
    # onDeactivate appears to be called like 3 times over the course of ending a match
    # the "stack" can go negative if you call too many times with 0, so it's important
    # that the calls to this function are perfectly matched
    li r4, 0
    bl set_mailbox

  on_deactivate_end:
    lwz r3, 8(sp)
    lwz r4, 12(sp)
    lwz r0, 20(sp)
    mtlr r0
    lwz sp, 0(sp)
    blr

get_mailbox:
  get_mailbox_start:
    # set up stack / preserve variables
    stwu sp, -16(sp)
    mflr r0
    stw r0, 20(sp)
    stw r4, 8(sp)
    stw r27, 12(sp)

    # get character-related pointer needed to call getInt/setInt function
    lwz r27, 0x60(r31)
    lwz r27, 0xD8(r27)
    lwz r27, 0x64(r27)

    # grab our "mailbox" variable, LA-Basic[74] (1000004A), using the getInt function
    mr r3, r27
    lis r4, 0x1000
    addi r4, r4, 0x004A
    lwz r12, 0(r27)
    lwz r12, 0x18(r12)
    mtctr r12
    bctrl

  get_mailbox_end:
    # r3 now contains the value of the variable
    lwz r4, 8(sp)
    lwz r27, 12(sp)
    lwz r0, 20(sp)
    mtlr r0
    lwz sp, 0(sp)
    blr

set_mailbox:
  set_mailbox_start:
    # set up stack / preserve variables
    stwu sp, -16(sp)
    mflr r0
    stw r0, 20(sp)
    stw r5, 8(sp)
    stw r27, 12(sp)

    # get character-related pointer needed to call getInt/setInt function
    lwz r27, 0x60(r31)
    lwz r27, 0xD8(r27)
    lwz r27, 0x64(r27)

    # set our mailbox variable by calling setInt (807ACA00)
    mr r3, r27
    lwz r12, 0(r27)
    lwz r12, 0x1C(r12)
    lis r5, 0x1000
    addi r5, r5, 0x004A
    mtctr r12
    bctrl

  set_mailbox_end:
    lwz r5, 8(sp)
    lwz r27, 12(sp)
    lwz r0, 20(sp)
    mtlr r0
    lwz sp, 0(sp)
    blr

set_camera_freeze:
  set_camera_freeze_start:
    # set up stack / preserve variables
    stwu sp, -16(sp)
    mflr r0
    stw r0, 20(sp)
    stw r3, 8(sp)
    stw r4, 12(sp)

    stw r5, 12(sp)

    # get camera instance pointer
    lwz r3, -0x41A8(r13)

    li r4, 7

    # call getCameraController/[CameraController]/(cm_camera_controller.o)
    lis r12, 0x8009
    ori r12, r12, 0xCA00
    mtctr r12
    bctrl

    lwz r4, 12(sp)

    # call setFreezeMode/[cmPhotoController]/(cm_controller_photo.o)
    lis r12, 0x800A
    ori r12, r12, 0x9600
    mtctr r12
    bctrl

  set_camera_freeze_end:
    lwz r3, 8(sp)
    lwz r4, 12(sp)
    lwz r0, 20(sp)
    mtlr r0
    lwz sp, 0(sp)
    blr

set_layer_disp:
  set_layer_disp_start:
    # set up stack / preserve variables
    stwu sp, -20(sp)
    mflr r0
    stw r0, 24(sp)
    stw r3, 8(sp)
    stw r4, 12(sp)
    stw r27, 16(sp)

    # setLayerDispStatus/[gfSceneRoot]/(gf_3d_scene.o)
    lis r12, 0x8000,
    ori r12, r12, 0xD234
    mtctr r12

    # get pointer to current scene?
    lis r27, 0x8059
    ori r27, r27, 0xFF80
    lwz r27, 0(r27)

    # for some reason, falcon calls this function with 0, 3, 2, and 6
    # here, we call it without 2, which allows articles to still display
    # r5 will contain whether to turn these layers on (0 or 1)
    li r4, 0
    mr r3, r27
    bctrl

    li r4, 3
    mr r3, r27
    bctrl

    li r4, 6
    mr r3, r27
    bctrl

  set_layer_disp_end:
    lwz r3, 8(sp)
    lwz r4, 12(sp)
    lwz r27, 16(sp)
    lwz r0, 24(sp)
    mtlr r0
    lwz sp, 0(sp)
    blr