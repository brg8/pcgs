The pcgs gem is for programmatically accessing coin dates, prices, etc. from http://pcgs.com/prices

# Example usage:  

## Pulling data from PCGS

### Use case 1:  

```
require "pcgs"  

wallet = PCGS::Wallet.new
# this will pull every bit of coin data from http://pcgs.com
```

The above code snippet will take ten or so minutes to run.

### Use case 2:

Go to http://pcgs.com/prices and copy the title of the coin type that you want to load into your wallet. Then use the following:

```
require "pcgs"

wallet = PCGS::Wallet.new("Lincoln Cent (Modern) (1959 to Date)")
# this will pull only the lincoln cent data
```

## Accessing coin data

```
require "pcgs"

wallet = PCGS::Wallet.new("Lincoln Cent (Modern) (1959 to Date)")

coin = wallet.coins[10]
# #<PCGS::Coin:0x007fc472494218 @pcgs_no=2853, @description=1959, @design="RB", @grade=65, @price=1, @grade_type="MS", @subtype="Lincoln Cent (Modern) (1959 to Date)", @type="Lincoln Cent (Modern) (1959 to Date)", @year="1959", @mint_mark="", @name="cent">

coin.pcgs_no
# 2853

coin.grade
# 65

coin.grade_type
# "MS"

coin.year
# "1959"

coin.mint_mark
# ""

```

For now you have to use `wallet.coins.find_all` to do large searches
