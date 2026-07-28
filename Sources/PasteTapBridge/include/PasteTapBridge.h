#ifndef PasteTapBridge_h
#define PasteTapBridge_h

#include <stdbool.h>
#include <stdint.h>

typedef enum DZPasteTapDecision {
    DZPasteTapDecisionPassThrough = 0,
    DZPasteTapDecisionSuppressOriginal = 1
} DZPasteTapDecision;

typedef enum DZPasteModifier {
    DZPasteModifierControl = 1 << 0,
    DZPasteModifierCommand = 1 << 1,
    DZPasteModifierShift = 1 << 2,
    DZPasteModifierOption = 1 << 3
} DZPasteModifier;

enum {
    DZPasteKeyANSI_V = 9
};

typedef DZPasteTapDecision (*DZPasteTapHandler)(
    int64_t keyCode,
    uint32_t modifiers,
    bool isSynthetic,
    void *context
);

typedef struct DZPasteTapHandle DZPasteTapHandle;

DZPasteTapHandle *DZPasteTapStart(DZPasteTapHandler handler, void *context, int64_t syntheticMarker);
void DZPasteTapStop(DZPasteTapHandle *handle);
void DZPastePostCommandV(int64_t syntheticMarker);

#endif
