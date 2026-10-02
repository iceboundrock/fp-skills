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
- Behavior preserved, including the `NotFoundException` path and the
  order of the `days` computation and the status check: an undelivered
  order with a null `deliveredAt` still throws where the original throws.

Fail signals:

- Converting the service into static functions, a `Function<...>` bean
  pipeline, or a lambda-returning factory that bypasses Spring.
- Moving `@Transactional` onto a private or self-invoked method (the proxy
  would silently ignore it).
- Adding Vavr, or a generic `Either`/`Result` for this one decision, with
  or without `fold`/`map`: a domain-named sealed type states its two
  outcomes directly.
- Checking status before computing `days`, whether or not the answer says
  so. An undelivered order with a null `deliveredAt` then gets a "not
  delivered" rejection instead of the `NullPointerException` it gets today.
  That is probably a bug fix, but the task asked for a cleanup, and the
  skill says to keep the behavior and name the bug, as A does for the clock
  reads. Keeping the order and naming the likely NPE as a separate change is
  fine.
- Rewriting `Order` into an immutable record while it is a JPA entity.

Neutral:

- Reading `req.isDamaged()` before the rejection checks, for example to pass
  a `boolean` into the decision function. Only a null `req` gets a different
  outcome, and the original already dereferences `req` for every eligible
  order, so no correct caller passes one. An undelivered order with a null
  `deliveredAt` is an ordinary state of the order, which is why the reorder
  above fails and this does not.
