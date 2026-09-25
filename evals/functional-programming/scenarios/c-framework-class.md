# C: Framework-required class (Java, Spring)

Tests over-application: does the agent fight the framework?

## Prompt

The refund logic in this service keeps growing and is hard to follow. Clean it
up using a functional style.

```java
@Service
public class RefundService {
    private final OrderRepository orders;
    private final PaymentGateway payments;
    private final Clock clock;

    public RefundService(OrderRepository orders, PaymentGateway payments, Clock clock) {
        this.orders = orders;
        this.payments = payments;
        this.clock = clock;
    }

    @Transactional
    public RefundResponse refund(long orderId, RefundRequest req) {
        Order order = orders.findById(orderId).orElseThrow(() -> new NotFoundException(orderId));
        long days = ChronoUnit.DAYS.between(order.getDeliveredAt(), clock.instant());
        BigDecimal amount;
        if (order.getStatus() != OrderStatus.DELIVERED) {
            return RefundResponse.rejected("not delivered");
        }
        if (days > 30) {
            return RefundResponse.rejected("window closed");
        }
        if (req.isDamaged()) {
            amount = order.getTotal();
        } else if (days <= 7) {
            amount = order.getTotal();
        } else {
            amount = order.getTotal().multiply(new BigDecimal("0.8"));
        }
        if (order.getCustomer().isVip()) {
            amount = amount.min(order.getTotal());
        } else {
            amount = amount.subtract(order.getShippingFee()).max(BigDecimal.ZERO);
        }
        payments.refund(order.getPaymentId(), amount);
        order.setStatus(OrderStatus.REFUNDED);
        order.setRefundedAmount(amount);
        return RefundResponse.approved(amount);
    }
}
```

## Rubric

Pass (all):

- `RefundService` stays a Spring `@Service` with constructor injection, and
  `refund` stays the public `@Transactional` entry point.
- The refund decision (eligibility and amount) moves into a pure method or
  small class/record that takes explicit values (order data, request, `now`)
  and returns an explicit decision, testable without Spring.
- Effects (`findById`, `payments.refund`, entity updates) stay in `refund`,
  in the same order.
- Behavior preserved, including the `NotFoundException` path. Checking
  status before computing `days` is fine (it avoids a null `deliveredAt`).

Fail signals:

- Converting the service into static functions, a `Function<...>` bean
  pipeline, or a lambda-returning factory that bypasses Spring.
- Moving `@Transactional` onto a private or self-invoked method (the proxy
  would silently ignore it).
- Adding Vavr, or a generic `Either`/`Result` with `fold`/`map` for this one
  decision, whose two outcomes a domain-named sealed type states directly.
- Rewriting `Order` into an immutable record while it is a JPA entity.
