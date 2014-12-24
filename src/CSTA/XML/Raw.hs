{-|

CSTA request/response packet processing.


CSTA header format:

@
|  0  |  1  |  2  |  3  |  4  |  5  |  6  |  7  |  8  | ...        |
|  Version  |   Length  |       InvokeID        | XML Message Body |
@

-}

module CSTA.XML.Raw where


import           Control.Exception
import           Data.Functor ((<$>))
import           Data.Binary.Get
import           Data.Binary.Put
import qualified Data.ByteString.Char8 as S
import qualified Data.ByteString.Lazy  as L
import qualified Data.ByteString.Lazy.Char8  as L8

import           System.IO
import           System.Posix.Syslog

import           Text.Printf

import           CSTA.Types
import           CSTA.XML.Request
import           CSTA.XML.Response


maybeSyslog :: Maybe LoggingOptions -> Priority -> String -> IO ()
maybeSyslog Nothing _ _ = return ()
maybeSyslog (Just LoggingOptions{..}) pri msg =
  withSyslog ident [PID] USER (logUpTo Debug) $ syslog pri msg


-- FIXME: error
sendRequest :: Maybe LoggingOptions -> Handle -> Int -> Request -> IO ()
sendRequest lopts h ix rq =
  let
    rawRequest = toXml rq
  in
    do
      maybeSyslog lopts Debug $
        "Sending request (invokeId=" ++ show ix ++ ") " ++
        (show $ L8.unpack rawRequest)
      L.hPut h $ runPut $ do
        putWord16be 0
        putWord16be . fromIntegral $ 8 + L.length rawRequest
        let invokeId = S.pack . take 4 $ printf "%04d" ix
        putByteString invokeId
        putLazyByteString rawRequest


-- FIXME: error
readResponse :: Maybe LoggingOptions -> Handle -> IO (Response, Int)
readResponse lopts h = do
  res <- try $ runGet readHeader <$> L.hGet h 8
  case res of
    Left err -> fail $ "Header: " ++ show (err :: SomeException)
    Right (len, invokeId) -> do
      resp <- L.hGet h (len - 8)
      maybeSyslog lopts Debug $
        "Received response (invokeId=" ++ show invokeId ++ ") " ++
        (show $ L8.unpack resp)
      return (fromXml resp, invokeId)
  where
    readHeader = do
      skip 2 -- version
      len <- fromIntegral <$> getWord16be
      ix  <- getByteString 4
      case S.readInt ix of
        Just (invokeId, "") -> return (len, invokeId)
        _ -> fail $ "Invalid InvokeID: " ++ show ix
