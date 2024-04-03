
type ExchangeRate = String -> Double
exchangeRateToPln :: ExchangeRate
exchangeRateToPln "EUR" = 4.3
exchangeRateToPln "GBP" = 4.9
exchangeRateToPln "CHF" = 3.9

getSwitzerlandCost :: Int -> Double -> ExchangeRate -> Double
getSwitzerlandCost days nightCost rate = fromIntegral days * nightCost * rate "CHF"

getUKCost :: Double -> ExchangeRate -> Double
getUKCost flightCost rate = 2.0 * flightCost * rate "GBP"

getFranceCost :: Double -> Double -> ExchangeRate -> Double
getFranceCost distance fuelCost rate = 2.0 * distance * fuelCost * rate "EUR"

calculateTotalCost :: ExchangeRate -> Double
calculateTotalCost exchangeRateToPln =
    let switzerlandCost = getSwitzerlandCost 7 100.0  exchangeRateToPln
        ukCost          = getUKCost 200.0             exchangeRateToPln
        franceCost      = getFranceCost 1000.0 1.5    exchangeRateToPln
        in (switzerlandCost + ukCost + franceCost)

calculateTotalCostMonadReader :: ExchangeRate -> Double
calculateTotalCostMonadReader = do
    switzerlandCost <- getSwitzerlandCost 7 100.0
    ukCost <- getUKCost 200.0
    franceCost <- getFranceCost 1000.0 1.5
    return (switzerlandCost + ukCost + franceCost)


changeToWarRates :: ExchangeRate -> ExchangeRate
changeToWarRates rates currency = 2 * rates currency

calculateTotalCostWhenWar :: ExchangeRate -> Double
calculateTotalCostWhenWar = do
    rates <- id
    return (calculateTotalCost (changeToWarRates rates))

local :: (r -> r) -> (r -> a) -> r -> a
local modifyEnv previousReader x = previousReader (modifyEnv x)