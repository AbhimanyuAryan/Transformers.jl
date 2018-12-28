using Flux: @treelike, onehotbatch

function getmask(ls)
    lens = map(length, ls)
    m = zeros(maximum(lens), length(lens))

    for (i, l) ∈ enumerate(ls)
        selectdim(selectdim(m, 2, i), 1, 1:length(l)) .= 1
    end
    reshape(m, (1, size(m)...))
end

getmask(m1, m2) = permutedims(m1, [2,1,3]) .* m2

struct Embed
    vocab
    unk
    embedding
end

@treelike Embed

function Embed(size::Int, vocab, unk="</unk>")
    if !(unk ∈ vocab)
        push!(vocab, unk)
    end

    device(Embed(vocab, unk, param(randn(size, length(vocab)))))
end

function (e::Embed)(xs)
    maxlen = maximum(map(length, xs))
    cat([e.embedding * onehotbatch([x; fill(e.unk, max(maxlen - length(x)))], e.vocab, e.unk) for x ∈ xs]...;dims=3), getmask(xs)
end

Base.show(io::IO, e::Embed) = print(io, "Embed($(size(e.embedding)[1]), vocab_size=$(length(e.vocab)), unk=$(e.unk))")