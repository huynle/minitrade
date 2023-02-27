# Minitrade

Minitrade is a personal automated trading system that integrates with and extends [Backtesting.py](https://github.com/kernc/backtesting.py) as the backtesting engine.

It can be either used as a standalone backtesting engine that:
- is fully compatible with Backtesting.py strategies with minor adaptions.
- supports multi-asset portfolio and rebalancing strategies.

Or it can be used as a full trading system that:
- Automatically executes trading strategies and submits orders.
- Manages strategy execution via web console.
- Runs on very low cost machines. 

Limitations as a backtesting engine:
- Multi-asset strategy only supports market order. 

Limitations (for now) as a trading system:
- Tested only on Linux
- Support only daily bar and market-on-open order
- Support only long positions
- Support only Interactive Brokers

On the other hand, Minitrade is intended to be easily adaptable to individual's needs.

## Installation

Minitrade requires `python=3.10.*`


If only used as a backtesting engine:

    $ pip install minitrade

If used as a trading system, continue with the following:

    $ minitrade init

For a detailed setup guide on Ubuntu, check out [Installation](install.md).

## Backtesting

Minitrade uses [Backtesting.py](https://github.com/kernc/backtesting.py) as the core library for backtesting and adds the capability to implement multi-asset strategies. 

### Single asset strattegy

For single asset strategies, those written for Backtesting.py can be easily adapted to work with Mintrade. The following SMA cross strategy illustrates what changes are necessary:

```python
from minitrade.backtest import Backtest, Strategy
from minitrade.backtest.core.lib import crossover

from minitrade.backtest.core.test import SMA, GOOG


class SmaCross(Strategy):
    def init(self):
        price = self.data.Close
        self.ma1 = self.I(SMA, price, 10, overlay=True)
        self.ma2 = self.I(SMA, price, 20, overlay=True)

    def next(self):
        if crossover(self.ma1, self.ma2):
            self.position().close()
            self.buy()
        elif crossover(self.ma2, self.ma1):
            self.position().close()
            self.sell()


bt = Backtest(GOOG, SmaCross, commission=.002)
stats = bt.run()
bt.plot()
```

1. Change to import from minitrade modules. Generally `backtesting` becomes `minitrade.backtest.core`.
2. Minitrade expects `Volume` data to be always avaiable. `Strategy.data` should be consisted of OHLCV.
3. Minitrade doesn't try to guess where to plot the indicators. So if you want to overlay the indicators on the main chart, set `overlay=True` explicitly.
4. `Strategy.position` is no longer a property but a function. Any occurrence of `self.position` should be changed to `self.position()`. 

That's it. 

[![plot of single-asset strategy](https://imgur.com/N3E2d6m)]

Also note that some original utility functions and strategy classes only make sense for single asset strategy. Don't use those in multi-asset strategies.

### Multi-asset strategy

Minitrade extends `Backtesting.py` to support backtesting of multi-asset strategies. 

Multi-asset strategies take a 2-level DataFrame as data input. For example, for a strategy class that intends to invest in AAPL and GOOG as a portfolio, the `self.data` should look like:

```
$ print(self.data)

                          AAPL                              GOOG 
                          Open  High  Low   Close Volume    Open  High  Low   Close Volume
Date          
2018-01-02 00:00:00-05:00 40.39 40.90 40.18 40.89 102223600 52.42 53.35 52.26 53.25 24752000
2018-01-03 00:00:00-05:00 40.95 41.43 40.82 40.88 118071600 53.22 54.31 53.16 54.12 28604000
2018-01-04 00:00:00-05:00 40.95 41.18 40.85 41.07 89738400 54.40 54.68 54.20 54.32 20092000
2018-01-05 00:00:00-05:00 41.17 41.63 41.08 41.54 94640000 54.70 55.21 54.60 55.11 25582000
2018-01-08 00:00:00-05:00 41.38 41.68 41.28 41.38 82271200 55.11 55.56 55.08 55.35 20952000
```

Like in `Backtesting.py`, `self.data` is `_Data` type that supports progressively revealing of data, and the raw DataFrame can be accessed by `self.data.df`. 

To facilitate indicator calculation, Multitrade has built-in integration with [pandas_ta](https://github.com/twopirllc/pandas-ta) a TA library. `pandas_ta` is accessible using `.ta` property of any DataFrame. Check out [here](https://github.com/twopirllc/pandas-ta#pandas-ta-dataframe-extension) for usage. `.ta` is also enhanced to support 2-level DataFrames. 

Using the earlier example, computing the 3-day SMA is simply:

```
$ print(self.data.df.ta.sma(3))

                                 AAPL       GOOG
Date                                            
2018-01-02 00:00:00-05:00         NaN        NaN
2018-01-03 00:00:00-05:00         NaN        NaN
2018-01-04 00:00:00-05:00   40.946616  53.898000
2018-01-05 00:00:00-05:00   41.163408  54.518500
2018-01-08 00:00:00-05:00   41.331144  54.926167
```

`self.I()` can take both DataFrame/Series and functions as parametes to define an indicator. If DataFrame/Series is given as input, it's expected to have exactly the same index as `self.data`. For example,

```
self.sma = self.I(self.data.df.ta.sma(3), name='SMA_3)
```

Within `Strategy.next()`, indicators are returned as type `_Array`, essentially `numpy.ndarray`, same as in `Backtesting.py`. The `.df` accessor returns either `DataFrame` or `Series` of the corresponding value. It's the caller's responsibility to know which exact type should be returned. `.s` accessor is also available but only as a syntax suger to return a `Series`. If the actual data is a DataFrame, `.s` throws a `ValueError`. 

A key addition to support multi-asset strategy is a `Strategy.alloc` attribute, which combined with `Strategy.rebalance()` API, allows to specify how cash value should be allocate among the different assets. 

Let's look at an example:

```
# this strategy evenly allocates cash into the assets
# that have the top 2 highest rate-of-change every day, 
# on condition that the ROC is possitive.

class TopPositiveRoc(Strategy):
    n = 10

    def init(self):
        roc = self.data.ta.roc(self.n)
        self.roc = self.I(roc, name='ROC')

    def next(self):
        roc = self.roc.df.iloc[-1]
        self.alloc.add(
            roc.nlargest(2).index, 
            roc > 0
        ).equal_weight()
        self.rebalance()
```

`self.alloc` keeps track of what assets you want to buy and how much weight you want to assign to each. 

At the beginning of each `Strategy.next()` call, `self.alloc` starts empty. 

You call `alloc.add()` to add assets to a candidate pool. `alloc.add()` takes either an index or a boolean Series as input. If it's an index, all asset in the index are added to the pool. If it's a boolean Series, index items having a `True` value are added to the pool. When multiple conditions are specified in the same call, the conditions are joined by logical `AND` and the resulted assets are added the the pool. You can also call `alloc.and()` multiple times which means logical `OR` in term of adding assets to the pool. 

Once you finish selecting what assets to buy, you call `alloc.equal_weight()` to indicate you want to allocate the total value of your equity equally to each selected asset.

And finally, you call `Strategy.rebalance()`, which will look at your current equity value, calculate the target value for each asset, calculate how many shares to buy or sell based on your current long/short positions, and generate orders that will bring the portfolio to the target allocation.

Run the above strategy on some DJIA components: 

[![plot of multi-asset strategy](https://imgur.com/a/RV9S9tj)]

