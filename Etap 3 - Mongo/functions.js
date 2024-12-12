function getBestDeals() {
    return db.deals.aggregate([{
        $lookup: {
            from: "stores",
            localField: "storeID",
            foreignField: "_id",
            as: "store"
        }
    }, {
        $sort: {
            dealRating: -1
        }
    }])
}

function insertDeal(deal) {
    const storeExists = db.stores.findOne({ _id: deal.storeID });
    if (!storeExists) {
        throw new Error("Store with given ID doesn't exist");
    }
    const result = db.deals.insertOne(deal);
    return result.insertedId;
}
function findGameDeals(title) {

    const regex = new RegExp(title, 'i');

    const deals = db.deals.find(
     { "game.title": { $regex: regex } },
     { pricing: 1, storeID: 1, dealRating: 1, game: 1 }
    );

    return deals;
}

function findGamesCheaperThan(maxSalePrice) {
    return db.deals.find(
      { "pricing.salePrice": { $lte: maxSalePrice } },
      { pricing: 1, storeID: 1, dealRating: 1, game: 1 }
    );
}

function advancedSearch(title, maxSalePrice, minSteamRating) {
    const regex = new RegExp(title, 'i');

    return db.deals.aggregate([{
        $lookup: {
            from: "stores",
            localField: "storeID",
            foreignField: "_id",
            as: "store"
        }
    }, {
        $sort: {
            dealRating: -1
        }
    }, {
        $match: {
            "game.title": { $regex: regex },
            "pricing.salePrice": { $lte: maxSalePrice },
            "steam.steamRatingPercent": { $gte: minSteamRating },
            "pricing.isOnSale": "1"
        }
    }])
}

function deleteDeal(dealID) {
    const objectID = new ObjectId(dealID);
    const result = db.deals.deleteOne({ _id: objectID });
    if (result.deletedCount == 1) {
        print("Deal deleted successfully")
    } else {
        throw Error("Deal with given id doesn't exist");
    }
}

function measureTime(command) {
    const t1 = new Date();
    for (let i = 0; i < 10_000; i++) {
        command();
    }
    const t2 = new Date();
    print("time: " + (t2 - t1) + "ms");
}

function insertDealTransaction(deal) {
    const session = db.getMongo().startSession();
    try {
        session.startTransaction();

        const storeExists = db.stores.findOne({ _id: deal.storeID });
        if (!storeExists) {
            throw new Error("Store with given ID doesn't exist");
        }

        const result = db.deals.insertOne(deal);

        session.commitTransaction();

        return result.insertedId;
    } catch (error) {
        session.abortTransaction();
        throw error;
    } finally {
        session.endSession();
    }
}

// MapReduce
db.deals.mapReduce(
  function () {
    emit(this.game.gameID, parseFloat(this.pricing.salePrice));
  },
  function (key, values) {
    return Array.sum(values) / values.length ;
  },
  { out: { inline: 1 }  }
);
