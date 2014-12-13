{-|

Usage: ./csta-test <EXTENSION> <NUMBER TO CALL>

-}

import Control.Concurrent
import Control.Monad

import Data.Aeson

import qualified Data.Text as T
import qualified Data.Text.Read as T
import System.Environment

import CSTA

main :: IO ()
main = do
  l <- getArgs
  when (length l /= 7) $
    getProgName >>=
    \pn ->
      error $ "Usage: " ++ pn ++
      " HOST PORT USER PWD SWITCH EXTENSION [NUMBER]"
  let [host, port', user, pwd, switch', ext', to] = l
      port = either (error "Bad port") fst $ T.decimal $ T.pack port'
      ext = T.pack ext'
      switch = SwitchName $ T.pack switch'

  as <- startSession host port (T.pack user) (T.pack pwd)
  aid <- controlAgent switch ext as
  handleEvents aid (print . encode)
  agentAction (MakeCall $ T.pack to) aid
  threadDelay $ 3*(10^7)
  releaseAgent aid
  stopSession as
