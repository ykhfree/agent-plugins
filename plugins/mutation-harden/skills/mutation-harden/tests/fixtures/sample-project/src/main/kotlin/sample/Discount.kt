package sample

import org.slf4j.LoggerFactory
import java.util.Locale

private val log = LoggerFactory.getLogger(Discount::class.java)

class Discount {
    // Orders of 10,000 or more get 10 percent off.
    fun rate(amount: Int): Int = if (amount >= 10_000) 10 else 0

    fun apply(amount: Int): Int {
        val rate = rate(amount)
        if (rate == 0) {
            log.debug("no discount for {}", amount)
        }
        return amount - amount * rate / 100
    }

    fun label(amount: Int): String {
        val locale: Locale = Locale.getDefault()
        return String.format(locale, "%d", apply(amount))
    }
}
