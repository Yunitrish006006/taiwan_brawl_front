package com.yunitrish.taiwanbrawl

import org.junit.Assert.*
import org.junit.Test

class CoupleWidgetPaletteTest {
    @Test fun unknownOrMissingPreferenceUsesDefault() {
        assertEquals("rose", CoupleWidgetPalette.normalized(null))
        assertEquals("rose", CoupleWidgetPalette.normalized("obsolete"))
        assertEquals(6, CoupleWidgetPalette.ids.size)
    }
    @Test fun everyChoiceHasAnIndependentBackgroundAndReadableForeground() {
        assertEquals(6, CoupleWidgetPalette.ids.map { CoupleWidgetPalette.background(it) }.toSet().size)
        for (id in CoupleWidgetPalette.ids) {
            assertEquals(id, CoupleWidgetPalette.normalized(id))
            assertEquals(0xFF, CoupleWidgetPalette.ink(id).ushr(24))
        }
    }
}
