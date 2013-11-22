{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
-- Evalute passed arguments with external interpreter
module System.Command.QQ.Eval
  ( Eval(..)
  ) where

import           Control.Applicative
import           Control.Concurrent
import           Control.Exception (evaluate)
import           Control.Monad
import           Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as T
import qualified Data.Text.Lazy.IO as T
import           System.Exit (ExitCode)
import qualified System.Process as P
import           System.IO (hFlush, hClose)

-- $setup
-- >>> import System.Command.QQ


-- | Different interesting return types for quasiquoters
--
-- Instances here mostly resemble the types of things in "System.Process"
class Eval r where
  eval :: String -> [String] -> r

-- | Most basic instance: nothing is known about what happened in external command
--
-- >>> [sh|echo hello world|] :: IO ()
-- hello world
instance Eval (IO ()) where
  eval command args = () <$ P.rawSystem command args

-- | Return exit code of the external process
--
-- >>> [sh|exit 0|] :: IO ExitCode
-- ExitSuccess
--
-- >>> [sh|exit 7|] :: IO ExitCode
-- ExitFailure 7
instance Eval (IO ExitCode) where
  eval command args = do
    (s, _, _) <- eval command args (T.pack "")
    return s

-- | Return stdout of the external process as 'Text'
--
-- Does not care whether external process has failed or not.
--
-- >>> [sh|echo -n hello world|] :: IO Text
-- "hello world"
instance Eval (IO Text) where
  eval command args = do
    (_, o, _) <- eval command args
    return o

-- | Return stdout of external process as 'String'
--
-- Does not care whether external process has failed or not.
--
-- >>> [sh|echo -n hello world|] :: IO String
-- "hello world"
instance Eval (IO String) where
  eval command args = T.unpack <$> eval command args

-- | Return exit code, stdout, and stderr of external process
--
-- >>> [sh|echo hello world; echo bye world >&2; exit 1|] :: IO (ExitCode, Text, Text)
-- (ExitFailure 1,"hello world\n","bye world\n")
instance
  ( s ~ ExitCode
  , o ~ Text
  , e ~ Text
  ) => Eval (IO (s, o, e)) where
  eval command args = eval command args (T.pack "")

-- | Return exit code, stdout, and stderr of the external process
-- and pass supplied 'Text' to its stdin
--
-- >>> [sh|while read line; do echo ${#line}; done|] "hello\nworld!\n"
-- (ExitSuccess,"5\n6\n","")
instance
  ( i ~ Text
  , o ~ (ExitCode, Text, Text)
  ) => Eval (i -> IO o) where
  eval = readProcessWithExitCode

readProcessWithExitCode :: String -> [String] -> Text -> IO (ExitCode, Text, Text)
readProcessWithExitCode cmd args input = do
    (Just ih, Just oh, Just eh, p) <-
        P.createProcess (P.proc cmd args)
          { P.std_in  = P.CreatePipe
          , P.std_out = P.CreatePipe
          , P.std_err = P.CreatePipe
          }

    m <- newEmptyMVar
    o <- T.hGetContents oh
    e <- T.hGetContents eh

    forkFinally (evaluate (T.length o)) (\_ -> putMVar m ())
    forkFinally (evaluate (T.length e)) (\_ -> putMVar m ())

    unless (T.null input) $ do
      T.hPutStr ih input
      hFlush ih
    hClose ih

    takeMVar m
    takeMVar m
    hClose oh
    hClose eh

    s <- P.waitForProcess p

    return (s, o, e)
