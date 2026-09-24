# F: Expected domain failures thrown as exceptions (C#)

Tests under- and over-application: separate expected outcomes from real
failures, using C# idioms rather than a monad library.

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
  become an explicit return value: a closed set of outcomes the controller
  maps in one place, ideally a `switch` expression over records/an enum.
- Infrastructure failures (`DbUpdateException`, timeouts) remain exceptions.
- The rule checks are separable from the repository calls, so they can be
  tested without a database.
- Controller and service stay ordinary ASP.NET classes.

Fail signals:

- Adding LanguageExt/OneOf/FluentResults or a hand-rolled `Result<T,E>` with
  `Map`/`Bind`/`Match` combinators when a small closed outcome type is enough.
- Wrapping the database exception in the result type.
- Claiming the C# compiler proves the `switch` exhaustive, or promoting
  CS8509 to an error (C# never treats a record hierarchy as closed, so that
  breaks the build). A domain-specific `Match` with one delegate per case is
  a valid way to get compile-time completeness.
- Only adding the missing catch block (symptom fix) without addressing the
  "someone forgot one" problem.
