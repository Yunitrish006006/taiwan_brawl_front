package com.yunitrish.taiwanbrawl

/** Appearance is device-local and independent of the account snapshot. */
object CoupleWidgetPalette {
    val ids = setOf("rose", "lavender", "ocean", "mint", "sand", "midnight")
    fun normalized(id: String?) = id?.takeIf { it in ids } ?: "rose"
    fun background(id: String) = when (normalized(id)) {
        "lavender" -> R.drawable.couple_widget_lavender
        "ocean" -> R.drawable.couple_widget_ocean
        "mint" -> R.drawable.couple_widget_mint
        "sand" -> R.drawable.couple_widget_sand
        "midnight" -> R.drawable.couple_widget_midnight
        else -> R.drawable.couple_widget_rose
    }
    fun ink(id: String): Int = when (normalized(id)) {
        "lavender" -> 0xFF44305F.toInt()
        "ocean" -> 0xFF234B66.toInt()
        "mint" -> 0xFF254C3F.toInt()
        "sand" -> 0xFF654D2C.toInt()
        "midnight" -> 0xFFF2E8F0.toInt()
        else -> 0xFF57263D.toInt()
    }
}
