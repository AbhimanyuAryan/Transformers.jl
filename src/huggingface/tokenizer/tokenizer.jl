using ..Transformers
using ..Basic
using FuncPipelines
using TextEncodeBase
using TextEncodeBase: trunc_and_pad, trunc_or_pad, nested2batch, nestedcall
using ValSplit
using JSON

load_tokenizer_config(model_name; kw...) = json_load(hgf_tokenizer_config(model_name; kw...))

function load_tokenizer(model_name; possible_files = nothing, config = nothing, kw...)
    possible_files = ensure_possible_files(possible_files, model_name; kw...)

    if TOKENIZER_CONFIG_FILE in possible_files
        tkr_config = load_tokenizer_config(model_name; kw...)
        tkr_type = get(tkr_config, :tokenizer_class, nothing)
    else
        tkr_config = nothing
        tkr_type = nothing
    end

    if isnothing(tkr_type)
        config = ensure_config(config, model_name; kw...)
        tkr_type = something(config.tokenizer_class, Symbol(config.model_type))
    end

    if tkr_type isa AbstractString
        m = match(r"(\S+)Tokenizer(Fast)?", tkr_type)
        isnothing(m) && error("Unknown tokenizer: $tkr_type")
        tkr_type = Symbol(lowercase(m.captures[1]))
    end

    return load_tokenizer(tkr_type, model_name; possible_files, config, tkr_config, kw...)
end

function load_tokenizer(
    tkr_type, model_name; force_fast_tkr = false, possible_files = nothing,
    config = nothing, tkr_config = nothing,
    kw...
)
    T = tokenizer_type(tkr_type)
    possible_files = ensure_possible_files(possible_files, model_name; kw...)
    config = ensure_config(config, model_name; kw...)

    isnothing(tkr_config) && TOKENIZER_CONFIG_FILE in possible_files &&
        (tkr_config = load_tokenizer_config(model_name; kw...))
    special_tokens = SPECIAL_TOKENS_MAP_FILE in possible_files ?
        load_special_tokens_map(hgf_tokenizer_special_tokens_map(model_name; kw...)) : nothing
    tkr_config = isnothing(tkr_config) ? (;) : tkr_config
    kwargs = extract_fast_tkr_kwargs(T, tkr_config, config, special_tokens)

    if FULL_TOKENIZER_FILE in possible_files || force_fast_tkr
        @assert FULL_TOKENIZER_FILE in possible_files "Forcely using fast tokenizer but cannot find $FULL_TOKENIZER_FILE in $model_name repo"
        tokenizer, vocab, process_config = load_fast_tokenizer(T, hgf_tokenizer(model_name; kw...))
    else
        slow_tkr_kwargs = extract_slow_tkr_kwargs(T, tkr_config, config, special_tokens)
        slow_files = slow_tkr_files(T)
        @assert all(Base.Fix2(in, possible_files), slow_files) "Cannot not find $slow_files or $FULL_TOKENIZER_FILE in $model_name repo"
        slow_files = map(file->hgf_file(model_name, file; kw...), slow_files)
        added_tokens_file = ADDED_TOKENS_FILE in possible_files ?
            hgf_tokenizer_added_token(model_name; kw...) : nothing
        tokenizer, vocab, process_config = load_slow_tokenizer(
            T, slow_files..., added_tokens_file, special_tokens; slow_tkr_kwargs...)
    end

    for (k, v) in process_config
        kwargs[k] = v
    end

    return encoder_construct(T, tokenizer, vocab; kwargs...)
end

tokenizer_type(type::Val) = type
@valsplit tokenizer_type(Val(type::Symbol)) = type

extract_fast_tkr_kwargs(type, tkr_cfg, config, special_tokens) =
    extract_fast_tkr_kwargs(type, config, special_tokens; tkr_cfg...)
extract_fast_tkr_kwargs(_type::Val{type}, config, special_tokens; tkr_cfg...) where type =
    extract_fast_tkr_kwargs(type, config, special_tokens; tkr_cfg...)
function extract_fast_tkr_kwargs(type::Symbol, config, special_tokens; tkr_cfg...)
    @debug "No extract_fast_tkr_kwargs handler registed for $type, using heuristic"
    vals = valarg_params(extract_fast_tkr_kwargs, Tuple{Val, Any, Any}, 1, Symbol)
    default_f = () -> heuristic_extract_fast_tkr_kwargs(config, tkr_cfg, special_tokens)
    return ValSplit._valswitch(Val(vals), Val(3), Core.kwfunc(extract_fast_tkr_kwargs), default_f,
                               tkr_cfg, extract_fast_tkr_kwargs, type, config, special_tokens)
end

extract_slow_tkr_kwargs(type, tkr_cfg, config, special_tokens) =
    extract_slow_tkr_kwargs(type, config, special_tokens; tkr_cfg...)
extract_slow_tkr_kwargs(_type::Val{type}, config, special_tokens; tkr_cfg...) where type =
    extract_slow_tkr_kwargs(type, config, special_tokens; tkr_cfg...)
function extract_slow_tkr_kwargs(type::Symbol, config, special_tokens; tkr_cfg...)
    @debug "No extract_slow_tkr_kwargs handler registed for $type, using heuristic"
    vals = valarg_params(extract_slow_tkr_kwargs, Tuple{Val, Any, Any}, 1, Symbol)
    default_f = () -> heuristic_extract_slow_tkr_kwargs(config, tkr_cfg, special_tokens)
    return ValSplit._valswitch(Val(vals), Val(3), Core.kwfunc(extract_slow_tkr_kwargs), default_f,
                               tkr_cfg, extract_slow_tkr_kwargs, type, config, special_tokens)
end

@valsplit slow_tkr_files(Val(type::Symbol)) = error("Don't know what files are need to load slow $type tokenizer.")

function _hgf_preprocess(
    ; trunc = nothing, fixedsize = false, trunc_end = :tail, pad_end = :tail,
    process = nothing, kws...
)
    truncf = get_trunc_pad_func(fixedsize, trunc, trunc_end, pad_end)
    maskf = get_mask_func(trunc, pad_end)
    if !isnothing(process)
        process = Pipeline{:token}(nestedcall(string_getvalue), 1) |> process
        if :segment in FuncPipelines.target_name.(process.pipes)
            process = process |>
                Pipeline{:segment}(truncf(1), :segment) |>
                Pipeline{:segment}(nested2batch, :segment)
        end
    else
        process = Pipeline{:token}(nestedcall(string_getvalue), 1)
    end
    return process |>
        Pipeline{:attention_mask}(maskf, :token) |>
        Pipeline{:token}(truncf(padsym), :token) |>
        Pipeline{:token}(nested2batch, :token)
end

function encoder_construct(type::Symbol, tokenizer, vocab; kwargs...)
    @debug "No encoder_construct handdler registed for $type, using default"
    return Basic.TransformerTextEncoder(tokenizer, vocab, _hgf_preprocess(; kwargs...); kwargs...)
end

include("utils.jl")
include("slow_tkr.jl")
include("fast_tkr.jl")
