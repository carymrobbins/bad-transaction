{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
module Main where

import Control.Monad.Catch
import Control.Monad.Except
import Control.Monad.Logger
import Data.Typeable
import Database.PostgreSQL.Query

newtype MyErr = MyErr String
  deriving stock (Show, Typeable)
  deriving anyclass (Exception)

main :: IO ()
main = do
  runStdoutLoggingT $ do
    c <- liftIO $ connectPostgreSQL "dbname=postgres host=localhost"
    liftIO $ putStrLn $ "---------------------------------------------------"

    do
      liftIO $ putStrLn "Example: fail a transacation with MonadError"
      runPgMonadT c $ pgExecute [sqlExp| create temp table foo(a int) |]
      liftIO $ putStrLn "begin transaction"
      res :: Either MyErr () <- runPgMonadT c $ pgWithTransaction $ runExceptT $ do
        _ <- pgExecute [sqlExp| insert into foo select 1 |]
        throwError $ MyErr "oh noes, rollback transaction!"
      liftIO $ print res
      -- But MonadError doesn't fail the transaction!
      rows :: [[Int]] <- runPgMonadT c $ pgQuery [sqlExp| select a from foo |]
      liftIO $ putStrLn $ "Rows are: " <> show rows
      liftIO $ putStrLn $ "^^ Note that we would want these rows to NOT have been inserted!"

    liftIO $ putStrLn $ "---------------------------------------------------"

    do
      liftIO $ putStrLn "Example: fail a transacation with MonadThrow"
      runPgMonadT c $ pgExecute [sqlExp| create temp table bar(a int) |]
      liftIO $ putStrLn "begin transaction"
      res :: Either MyErr () <- try $ runPgMonadT c $ pgWithTransaction $ do
        _ <- pgExecute [sqlExp| insert into foo select 1 |]
        throwM $ MyErr "oh noes, rollback transaction!"
      liftIO $ print res
      -- Exceptions are properly handled by pgWithTransaction.
      rows :: [[Int]] <- runPgMonadT c $ pgQuery [sqlExp| select a from bar |]
      liftIO $ putStrLn $ "Rows are: " <> show rows
      liftIO $ putStrLn $ "^^ This is ideal; we want the result to be zero rows."
