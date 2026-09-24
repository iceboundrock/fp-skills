# G: One-method strategy classes (Python)

Tests recognition: first-class functions can replace single-method classes,
but the change must stay proportional to the request.

## Prompt

Add an "overnight" shipping option: $25 flat, only allowed for parcels under
5 kg. For heavier parcels, raise `ValueError`, as the factory does for an
unknown method. The other options don't check weight; leave them as they are.
The shipping module is ours, so feel free to tidy it while you are in there.

```python
# shipping.py
from abc import ABC, abstractmethod
from decimal import Decimal


class ShippingStrategy(ABC):
    @abstractmethod
    def cost(self, weight_kg: Decimal) -> Decimal: ...


class StandardShipping(ShippingStrategy):
    def cost(self, weight_kg: Decimal) -> Decimal:
        return Decimal("5") + weight_kg * Decimal("0.5")


class ExpressShipping(ShippingStrategy):
    def cost(self, weight_kg: Decimal) -> Decimal:
        return Decimal("15") + weight_kg * Decimal("1.2")


class PickupShipping(ShippingStrategy):
    def cost(self, weight_kg: Decimal) -> Decimal:
        return Decimal("0")


class ShippingStrategyFactory:
    def create(self, method: str) -> ShippingStrategy:
        if method == "standard":
            return StandardShipping()
        if method == "express":
            return ExpressShipping()
        if method == "pickup":
            return PickupShipping()
        raise ValueError(f"unknown shipping method: {method}")


# only usage, in checkout.py
cost = ShippingStrategyFactory().create(order.shipping_method).cost(order.weight_kg)
```

## Rubric

Pass (all):

- Adds overnight with the weight rule, raising `ValueError` at 5 kg and above.
- Recognizes that each class is one stateless function plus a factory, and
  either replaces them with plain functions in a dict keyed by method name
  (updating the single call site) or explains why it kept the classes.
- The change stays inside `shipping.py` and its one call site.

Fail signals:

- Adds a fourth subclass and a fourth `if` without noticing the pattern
  (under-application, given the explicit invitation to tidy).
- Replaces classes with a registry decorator, `Protocol` plus plugin
  discovery, `functools.partial` chains, or other machinery with more
  concepts than the original.
- Changes public behavior for unknown methods, or adds weight checks to the
  existing options.
