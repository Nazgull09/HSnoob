{-#LANGUAGE RecordWildCards#-}
module Genes where

import Control.Monad.Random;
import Control.Monad;  
import Data.Functor;
import Data.Function(on)
import Data.List(sortBy);
import Data.Foldable(maximumBy);

type Chromosome = [Int]
type Population = [Chromosome]
type GenRand = RandT StdGen IO

data EvOptions = EvOptions{
                populationSize::Int,
                individLength::Int,
                maxGeneration::Int,
                fitness::Fitness,
                targetFitness::Double,
                mutationChance::Double,
                elitePart::Double
                }

type Fitness = Chromosome -> Double

randChoice :: Rational -> GenRand a -> GenRand a -> GenRand a
randChoice chance th els = join (fromList [(th, chance), (els, 1 - chance)])        --fromList - часть рандома, выдает рандом из списка по вероятности

nextPopulation::EvOptions->Population->GenRand Population
nextPopulation EvOptions {..} pop = do
        newPop' <-liftM concat $ replicateM (nonElite `div` 2) $ do
            a1 <- takeChr
            b1 <- takeChr
            (a2, b2) <- crossingover a1 b1
            a3 <- applyMutation a2
            b3 <- applyMutation b2
            return [a3, b3]
        let newPop = elite ++ newPop'
        return $ if length newPop <= length pop then newPop else tail newPop
        where   fits = toRational <$> fitness  <$> pop                              --map fitness pop
                maxfit = maximum fits
                chances = zip pop ((/maxfit) <$> fits)
                takeChr = fromList chances
                -- с некоторым шансом либо смутировать, либо просто венуть хромосому с
                applyMutation c = randChoice (toRational mutationChance) (mutateChromosome c) (return c) 
                sortedPop = snd $ unzip $ sortBy (compare `on` fst) $ zip (fitness <$> pop) pop 
                -- другой подход к сортировке, иквабл для хромосомы
                elite = take (ceiling $ fromIntegral (length pop) * elitePart) sortedPop
                nonElite = length pop - length elite

randChromosome::Int->GenRand Chromosome

randChromosome n = replicateM n randBool
        where randBool = uniform [0, 1]
        
randPopulation::Int->Int->GenRand Population
randPopulation n m = replicateM n $ randChromosome m

mutateChromosome::Chromosome->GenRand Chromosome
mutateChromosome chr = do                                --заменяем н-ый элемент инверсией
        n <- uniform [0..length chr - 1]
        return $ invertAt n chr
        where invertAt n orig = take n orig ++ [el] ++ drop (n+1) orig
                where el = if orig !! n == 0 then 1 :: Int else 0

crossingover::Chromosome->Chromosome->GenRand (Chromosome, Chromosome)
crossingover a b = do
        n <- uniform [0,3..length a -1]
        return $ f n
        where f n = (take n a ++ drop n b, take n b ++ drop n a)

runEvol::EvOptions->Int->Population->IO (Int,Population)
runEvol opts@(EvOptions{..}) n pop =
   if (fitness (best pop) >= targetFitness)||(n>=maxGeneration)
   then return (n,pop)
   else do
        when(n `mod` 10 == 0) $ print $ show n ++ "-" ++ show pop
        rng <- newStdGen
        newPop <- evalRandT (nextPopulation opts pop) rng
        runEvol opts (n+1) newPop
   where best p = snd . maximumBy (compare `on` fst) $ zip (fitness <$> p) p


initEvol::EvOptions->IO (Int,Population)
initEvol opts = do 
   rng <- newStdGen
   initPopulation <- evalRandT (randPopulation (populationSize opts) (individLength opts)) rng
   result <- runEvol opts 0 initPopulation
   return result