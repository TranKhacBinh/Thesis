include("./Dataset.jl")
include("./UtilityGenerator.jl")

ds_names = ["chess", "mushrooms", "connect", "accidents", "t20i6d100k", "t25i10d10k", "foodmart", "pumsb", "retail"]
int_util_ranges = [1:10, 1:10, 1:10, 1:10, 1:10, 1:10, 1:10, 1:10, 1:10]
ext_util_ranges = [1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0, 1.0:1000.0]

for (i, ds_name) in enumerate(ds_names)
    transactions_no_util = load_transactions_no_util("./TransactionsDB/$(ds_name).txt")

    items = reduce(union, transactions_no_util)
    util_table = gen_ext_util(items, ext_util_ranges[i])
    transactions = gen_int_util(transactions_no_util, int_util_ranges[i])

    ds = Dataset(ds_name, transactions, util_table)
    save(ds)

    clone_ds = load_dataset(ds_name)
    println("$(ds_name): ", ds == clone_ds)
end