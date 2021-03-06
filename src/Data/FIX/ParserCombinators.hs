-- Module  : Data.FIX.ParserCombinators
-- License : LGPL-2.1 

{-# LANGUAGE BangPatterns #-}

module Data.FIX.ParserCombinators 
    ( toTag
    , toString
    , toInt'
    , toInt
    , toDouble
    , toBool
    , toTimestamp
    , toTimeOnly
    , toChar
    , toDateOnly
    , toTime
    , toMonthYear

    , skipToken

    -- exporting Attoparsec
    , Data.Attoparsec.Parser
    , Data.Attoparsec.Zepto.parse
	) where

import Prelude hiding ( null, tail, head )
import Data.Attoparsec ( Parser )
import qualified Data.Attoparsec.Zepto ( parse )
import Data.Attoparsec.Char8 
    ( skipWhile, signed, char, char8, anyChar, takeWhile1, decimal, double )
import Data.Char ( ord )
import Data.ByteString hiding ( pack, putStrLn )
import Control.Applicative ( (<$>), (<|>), (*>) )
import Control.Monad (void)
import System.Time ( CalendarTime (..) )
import qualified Data.FIX.Common as FIX ( delimiter )


skipFIXDelimiter :: Parser ()
skipFIXDelimiter = void (char8 FIX.delimiter) 


toDouble :: Parser Double
toDouble =  signed $ do 
    a <- decimal :: Parser Integer
    (!m, !e) <- (char '.' *> (extract_decimals <$> toString)) <|> (skipFIXDelimiter >> return (0, 1))
    return $ fromIntegral a + fromIntegral m / fromIntegral e
    where
        extract_decimals :: ByteString -> (Int, Int)
	extract_decimals = foldl' helper (0, 1)
		where
			helper !(!m, !e) c = (m * 10 + fromIntegral c - ord '0', 10 * e)

parseIntTill :: Char -> Parser Int
parseIntTill c = do
    i <- signed decimal
    _ <- char8 c
    return i

toInt' :: ByteString -> Int
toInt' = helper 0 
           where 
                helper i j 
                    | null j    = i
                    | otherwise =   
                        helper (10 * i + fromIntegral (head j) - ord '0') (tail j)
                    
toInt :: Parser Int
toInt = parseIntTill FIX.delimiter


toChar :: Parser Char
toChar = do
    c <- anyChar
    skipFIXDelimiter
    return c

toString :: Parser ByteString
toString = do 
    str <- takeWhile1 (/= FIX.delimiter)
    skipFIXDelimiter
    return str


toTag :: Parser Int
toTag = parseIntTill '='
    
toBool :: Parser Bool
toBool = do
    c <- char 'Y' <|> char 'N'
    skipFIXDelimiter
    case c of
        'Y' -> return True
        'N' -> return False
        _ -> error "wrong boolean FIX value"

toSecMillis :: Parser (Int, Int)
toSecMillis = do
   (sec, mil) <- read_sec_millis <|> (toInt >>= (\s -> return (s, 0))) 
   return (sec, mil)
   where
        read_sec_millis :: Parser (Int, Int)
        read_sec_millis = do
            sec' <- parseIntTill '.'
            mil' <- toInt
            return (sec', mil')

-- one milli seconds is 10^9 picoseconds 
picosPerMilli :: Int
picosPerMilli = 1000000000

toTimestamp :: Parser CalendarTime
toTimestamp = do
   i <- parseIntTill '-'
   let year  = i `div` 10000
   let rest  = i `mod` 10000
   let month = rest `div` 100
   let day   = rest `mod` 100
   hours   <- parseIntTill ':'
   minutes <- parseIntTill ':'
   (sec, milli) <- toSecMillis
   return CalendarTime {
       ctYear  = year
     , ctMonth = toEnum $ month - 1
     , ctDay   = day
     , ctHour  = hours
     , ctMin   = minutes
     , ctSec   = sec
     , ctPicosec = toInteger $ milli * picosPerMilli
     , ctWDay  = toEnum 0
     , ctYDay  = 0
     , ctTZName = "UTC"
     , ctTZ    = 0
     , ctIsDST = True
   }

toTimeOnly :: Parser CalendarTime
toTimeOnly = do
   hours   <- parseIntTill ':'
   minutes <- parseIntTill ':'
   (sec, milli) <- toSecMillis
   return CalendarTime {
       ctYear  = 0
     , ctMonth = toEnum 0
     , ctDay   = 0
     , ctHour  = hours
     , ctMin   = minutes
     , ctSec   = sec
     , ctPicosec = toInteger $ milli * picosPerMilli
     , ctWDay  = toEnum 0
     , ctYDay  = 0
     , ctTZName = "UTC"
     , ctTZ    = 0
     , ctIsDST = True
   }

toDateOnly :: Parser CalendarTime
toDateOnly = do
   i <- toInt
   let year  = i `div` 10000
   let rest  = i `mod` 10000
   let month = rest `div` 100
   let day   = rest `mod` 100
   return CalendarTime {
       ctYear  = year
     , ctMonth = toEnum $ month - 1
     , ctDay   = day
     , ctHour  = 0
     , ctMin   = 0 
     , ctSec   = 0
     , ctPicosec = 0
     , ctWDay  = toEnum 0
     , ctYDay  = 0
     , ctTZName = "UTC"
     , ctTZ    = 0
     , ctIsDST = True
   }


toMonthYear :: Parser CalendarTime
toMonthYear = do
   i <- toInt
   let year  = i `div` 100
   let month = i `mod` 100
   return CalendarTime {
       ctYear  = year
     , ctMonth = toEnum $ month - 1
     , ctDay   = 0
     , ctHour  = 0
     , ctMin   = 0 
     , ctSec   = 0
     , ctPicosec = 0
     , ctWDay  = toEnum 0
     , ctYDay  = 0
     , ctTZName = "UTC"
     , ctTZ    = 0
     , ctIsDST = True
   }

toTime :: Parser CalendarTime
toTime = toTimestamp 
          <|> toTimeOnly 
          <|> toDateOnly

skipToken :: Parser ()
skipToken = skipWhile (FIX.delimiter /=)
