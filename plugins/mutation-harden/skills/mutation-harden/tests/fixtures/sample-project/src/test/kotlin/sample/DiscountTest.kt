package sample

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals

class DiscountTest {
    @Test
    fun `large order gets ten percent off`() {
        assertEquals(18_000, Discount().apply(20_000))
    }

    @Test
    fun `small order gets no discount`() {
        assertEquals(5_000, Discount().apply(5_000))
    }

    @Test
    fun `label shows the discounted amount`() {
        assertEquals("18000", Discount().label(20_000))
    }
}
