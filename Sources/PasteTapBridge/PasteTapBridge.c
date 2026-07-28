#include "PasteTapBridge.h"

#include <ApplicationServices/ApplicationServices.h>
#include <Carbon/Carbon.h>
#include <stdlib.h>

struct DZPasteTapHandle {
    CFMachPortRef tap;
    CFRunLoopSourceRef source;
    DZPasteTapHandler handler;
    void *context;
    int64_t syntheticMarker;
};

static uint32_t DZModifiersFromFlags(CGEventFlags flags) {
    uint32_t modifiers = 0;
    if ((flags & kCGEventFlagMaskControl) != 0) {
        modifiers |= DZPasteModifierControl;
    }
    if ((flags & kCGEventFlagMaskCommand) != 0) {
        modifiers |= DZPasteModifierCommand;
    }
    if ((flags & kCGEventFlagMaskShift) != 0) {
        modifiers |= DZPasteModifierShift;
    }
    if ((flags & kCGEventFlagMaskAlternate) != 0) {
        modifiers |= DZPasteModifierOption;
    }
    return modifiers;
}

static CGEventRef DZPasteTapCallback(
    CGEventTapProxy proxy,
    CGEventType type,
    CGEventRef event,
    void *userInfo
) {
    (void)proxy;
    DZPasteTapHandle *handle = (DZPasteTapHandle *)userInfo;
    if (handle == NULL || handle->handler == NULL) {
        return event;
    }
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        return event;
    }
    if (type != kCGEventKeyDown) {
        return event;
    }

    int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    int64_t userData = CGEventGetIntegerValueField(event, kCGEventSourceUserData);
    bool isSynthetic = userData == handle->syntheticMarker;
    DZPasteTapDecision decision = handle->handler(
        keyCode,
        DZModifiersFromFlags(CGEventGetFlags(event)),
        isSynthetic,
        handle->context
    );
    return decision == DZPasteTapDecisionSuppressOriginal ? NULL : event;
}

DZPasteTapHandle *DZPasteTapStart(DZPasteTapHandler handler, void *context, int64_t syntheticMarker) {
    DZPasteTapHandle *handle = calloc(1, sizeof(DZPasteTapHandle));
    if (handle == NULL) {
        return NULL;
    }
    handle->handler = handler;
    handle->context = context;
    handle->syntheticMarker = syntheticMarker;

    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    handle->tap = CGEventTapCreate(
        kCGSessionEventTap,
        kCGHeadInsertEventTap,
        kCGEventTapOptionDefault,
        mask,
        DZPasteTapCallback,
        handle
    );
    if (handle->tap == NULL) {
        free(handle);
        return NULL;
    }

    handle->source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, handle->tap, 0);
    if (handle->source == NULL) {
        CFMachPortInvalidate(handle->tap);
        CFRelease(handle->tap);
        free(handle);
        return NULL;
    }

    CFRunLoopAddSource(CFRunLoopGetMain(), handle->source, kCFRunLoopCommonModes);
    CGEventTapEnable(handle->tap, true);
    return handle;
}

void DZPasteTapStop(DZPasteTapHandle *handle) {
    if (handle == NULL) {
        return;
    }
    if (handle->source != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), handle->source, kCFRunLoopCommonModes);
        CFRelease(handle->source);
    }
    if (handle->tap != NULL) {
        CGEventTapEnable(handle->tap, false);
        CFMachPortInvalidate(handle->tap);
        CFRelease(handle->tap);
    }
    free(handle);
}

void DZPastePostCommandV(int64_t syntheticMarker) {
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    CGEventRef down = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, true);
    CGEventRef up = CGEventCreateKeyboardEvent(source, (CGKeyCode)kVK_ANSI_V, false);
    if (down != NULL) {
        CGEventSetFlags(down, kCGEventFlagMaskCommand);
        CGEventSetIntegerValueField(down, kCGEventSourceUserData, syntheticMarker);
        CGEventPost(kCGHIDEventTap, down);
        CFRelease(down);
    }
    if (up != NULL) {
        CGEventSetFlags(up, kCGEventFlagMaskCommand);
        CGEventSetIntegerValueField(up, kCGEventSourceUserData, syntheticMarker);
        CGEventPost(kCGHIDEventTap, up);
        CFRelease(up);
    }
    if (source != NULL) {
        CFRelease(source);
    }
}
