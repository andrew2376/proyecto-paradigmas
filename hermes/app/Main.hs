{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

import Web.Scotty
import Crypto.Hash
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Aeson
import GHC.Generics

data VoyagerReport = VoyagerReport
  { mission_id :: String,
    classification :: String,
    confidence :: Double,
    timestamp_utc :: String,
    rule_chain :: [String]
  }
  deriving (Show, Generic)

instance FromJSON VoyagerReport
instance ToJSON VoyagerReport

calculateSHA256 :: BL.ByteString -> String
calculateSHA256 input =
  show (hashlazy input :: Digest SHA256)

main :: IO ()
main = do
  putStrLn "HERMES SATELLITE ONLINE"
  putStrLn "Listening on port 3000..."

  scotty 3000 $ do

    post "/receive" $ do

      bodyData <- body

      let sha256Hash = calculateSHA256 bodyData

      let decodedPayload =
            decode bodyData :: Maybe VoyagerReport

      let enrichedMessage =
            object
              [ "payload" .= decodedPayload,
                "hermes" .=
                  object
                    [ "satellite_id" .= ("HERMES-01" :: String),
                      "received_timestamp"
                        .= ("2041-10-17T14:23:02Z" :: String),
                      "sha256" .= sha256Hash
                    ]
              ]

      json enrichedMessage