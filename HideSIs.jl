include("./Dataset.jl")

function hide_sis(ds_name::String, mut::Float64, sip::Float64, halg::Function)
    ds = load_dataset(ds_name)
    huis = load_huis(ds_name, mut)
    sis = load_sis(ds_name, mut, sip)

    min_util = (ds.info.total_util * mut) / 100
	runtime = @elapsed sanitized_transactions = halg(ds.transactions, ds.util_table, sis, huis, min_util)
	
    return sanitized_transactions, runtime
end

function hide_sis!(ds_name::String, mut::Float64, sip::Float64, halg::Function)
    sanitized_transactions, runtime = hide_sis(ds_name, mut, sip, halg)

    output_path = joinpath(pwd(), "Outputs", ds_name, "mut=$(mut)", "sip=$(sip)", "halg=$(halg)")
    mkpath(output_path)
    save(sanitized_transactions, joinpath(output_path, "sanitized_transactions.txt"))
    writelines(["$(runtime)"], joinpath(output_path, "runtime.txt"))
end