# Dangerous transactions

_with Haskell and PostgreSQL_

## MonadError

Don't use `MonadError` when executing transactions! Unfortunately, `throwError`
does not trigger a rollback in your transaction and you'll inadvertantly
be committing bad data to your database!

Instead, use `MonadThrow` and make your error an `Exception`. This way,
the transaction handling can properly catch the exception, execute a
rollback, then rethrow the exception.

Below is an example demonstrating the problem and solution (see
[bad-monaderror/Main.hs](bad-monaderror/Main.hs) for the full
implementation) -

```
% stack run bad-monaderror
...
---------------------------------------------------
Example: fail a transacation with MonadError
[Debug]  create temp table foo(a int)
begin transaction
[Debug]  insert into foo select 1
Left (MyErr "oh noes, rollback transaction!")
[Debug]  select a from foo
Rows are: [[1]]
^^ Note that we would want these rows to NOT have been inserted!
---------------------------------------------------
Example: fail a transacation with MonadThrow
[Debug]  create temp table bar(a int)
begin transaction
[Debug]  insert into foo select 1
Left (MyErr "oh noes, rollback transaction!")
[Debug]  select a from bar
Rows are: []
^^ This is ideal; we want the result to be zero rows.
```
