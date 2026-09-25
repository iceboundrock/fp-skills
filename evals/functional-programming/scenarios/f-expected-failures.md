# F: Expected domain failures thrown as exceptions (C#)

Tests under- and over-application: separate expected outcomes from real
failures, using C# idioms rather than a monad library. A domain-named
outcome and a generic `Result<TransferSuccess, TransferError>` are both
acceptable shapes; the rubric grades what the type exposes, not its name.

## Prompt

Every time we add a transfer rule the controller grows another catch block,
and last week someone forgot one and users got a 500. Improve the design.

```csharp
public class TransferService
{
    private readonly IAccountRepository _accounts;
    public TransferService(IAccountRepository accounts) => _accounts = accounts;

    public async Task Transfer(Guid from, Guid to, decimal amount)
    {
        var source = await _accounts.Find(from) ?? throw new AccountNotFoundException(from);
        var target = await _accounts.Find(to) ?? throw new AccountNotFoundException(to);
        if (source.Frozen) throw new AccountFrozenException(from);
        if (source.Balance < amount) throw new InsufficientFundsException(from, amount);
        if (amount > source.DailyLimitRemaining) throw new DailyLimitExceededException(from);

        source.Balance -= amount;
        target.Balance += amount;
        await _accounts.SaveBoth(source, target); // may throw DbUpdateException
    }
}

[ApiController, Route("transfers")]
public class TransfersController : ControllerBase
{
    private readonly TransferService _service;
    public TransfersController(TransferService service) => _service = service;

    [HttpPost]
    public async Task<IActionResult> Post(TransferDto dto)
    {
        try
        {
            await _service.Transfer(dto.From, dto.To, dto.Amount);
            return Ok();
        }
        catch (AccountNotFoundException e) { return NotFound(e.Message); }
        catch (AccountFrozenException e) { return Conflict(e.Message); }
        catch (InsufficientFundsException e) { return UnprocessableEntity(e.Message); }
        // DailyLimitExceededException is not handled -> 500
    }
}
```

## Rubric

Pass (all):

- Business rejections (not found, frozen, insufficient funds, daily limit)
  become an explicit return value that callers must handle: either a
  domain-named closed outcome (`TransferOutcome`: `Completed | NotFound(id)
  | Frozen(id) | InsufficientFunds | DailyLimitExceeded`) or a generic
  `Result<TransferSuccess, TransferError>` whose `TransferError` is that
  closed set. The controller maps it in one place, ideally a `switch`
  expression over records/an enum.
- Infrastructure failures (`DbUpdateException`, timeouts) are not
  mechanically swallowed: they remain exceptions, or the answer states a
  reason the controller should treat one as a normal outcome.
- The rule checks are separable from the repository calls, so they can be
  tested without a database.
- Controller and service stay ordinary ASP.NET classes.

Fail signals:

- Adding LanguageExt/OneOf/FluentResults for this one service, or a
  `Result<T,E>` module with `Map`/`Bind`/`Match` combinators that nothing in
  the answer calls. A plain `Result` record that the controller switches on
  is fine.
- A nullable rejection (`Task<TransferRejection?>`, `null` on success) or a
  `TryTransfer(..., out rejection)` pair. Success is signalled by the absence
  of a value, so the return type does not name the closed outcome set, and
  the controller maps success in a null check and rejections in a separate
  `Match`/`switch`. `Completed` as an empty record, or `Result<Unit, E>`, is
  the right shape when success carries no data.
- Wrapping the database exception in the result type without a stated
  reason.
- Claiming the C# compiler proves a `switch` over records exhaustive, or
  promoting CS8509 to an error while a record switch has no `_` arm (C# never
  treats a record hierarchy as closed, so that breaks the build). A
  domain-specific `Match` with one delegate per case is a valid way to get
  compile-time completeness.
- An enum outcome switched with a `_` arm, which hides a member added later
  from CS8509. An enum switch listing every member with no `_` arm is valid.
- Only adding the missing catch block (symptom fix) without addressing the
  "someone forgot one" problem.
