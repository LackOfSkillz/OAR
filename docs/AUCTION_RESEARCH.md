# Auction addon research (2026-11-16)

Gary asked: "What other auction features should we add to outrider. Research other auction addons for ideas."

## Already in Outrider
- Shopping panel (GearShop): Training, Weapons, Armor, Bags (bags added 2026-11-16).
- Buying: a Buy button with a confirm bar, one click per purchase (AHBuy).
- Prices: full scan, price history, prices on tooltips.
- AuctionHelper: suggested price with undercut and floor; warns when vendor value or deposit makes the sale a loss; lists your auctions that have been undercut.

## Forever-specific addons to detect and step aside for (rule 8)
- auxForever 0.8.2 (beta): https://www.curseforge.com/wow/addons/auxforever
- Auctioneer (Forever) 4.0.6: https://www.curseforge.com/wow/addons/auctioneer-forever
- CraftProfit Forever (beta): https://www.curseforge.com/wow/addons/craftprofit-forever
- Journalator lists Forever as supported: https://www.curseforge.com/wow/addons/journalator

Forever builds of Auctionator, TSM, Postal and Auctipus were not confirmed.

## Client limits
- ReplicateItems (full scan) runs at most once per 15 minutes, account-wide.
- PostItem, PlaceBid, CancelAuction and PostCommodity need a hardware click.
- Deal finders may only alert (D18). The buy stays Gary's click.

## Candidate features (not built)
1. Selling list: items in your bags worth posting, each with a suggested price, "a vendor pays more" flags, and the deposit, cut and net.
2. Deal alerts: during a scan, items priced below vendor value or well under their usual price. A toast only.
3. Shopping lists for levelling: arrows or bullets, food and water, bandages, saved and run in one go.
4. Ledger for AH sales and expiries, AH mail and spending on vendors, repairs and flights. This extends Ledger.
5. Open AH mail by type (sold, expired, won), one click per mail.
6. Crafting profit: reagent cost against sale price for Gary's professions.
7. Disenchant value on tooltips, for an enchanter.
8. Price trend on tooltips: today's price against the 14-day median.
