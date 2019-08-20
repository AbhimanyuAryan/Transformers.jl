# Transformers.jl

*Julia implementation of Transformers models*

This is the documentation of `Transformers`: The Julia solution for using Transformer models based on [Flux.jl](https://fluxml.ai/)


## Installation

In the Julia REPL:

```jl
julia> ]add Transformers
```

For using GPU, install & build:

```jl
julia> ]add CuArrays; build
```


## Implemented model
You can find the code in `example` folder.

-   [Attention is all you need](https://arxiv.org/abs/1706.03762)
-   [Improving Language Understanding by Generative Pre-Training](https://s3-us-west-2.amazonaws.com/openai-assets/research-covers/language-unsupervised/language_understanding_paper.pdf)
-   [BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding](https://arxiv.org/abs/1810.04805)


## Example

Take a simple encoder-decoder model construction of machine translation task. With `Transformers.jl` we can easily define/stack the models. 

```julia
using Transformers
using Transformers.Basic

encoder = Stack(
    @nntopo(e → pe:(e, pe) → x → x → $N),
    PositionEmbedding(512),
    (e, pe) -> e .+ pe,
    Dropout(0.1),
    [Transformer(512, 8, 64, 2048) for i = 1:N]...
)

decoder = Stack(
    @nntopo((e, m, mask):e → pe:(e, pe) → t → (t:(t, m, mask) → t:(t, m, mask)) → $N:t → c),
    PositionEmbedding(512),
    (e, pe) -> e .+ pe,
    Dropout(0.1),
    [TransformerDecoder(512, 8, 64, 2048) for i = 1:N]...,
    Positionwise(Dense(512, length(labels)), logsoftmax)
)

function loss(src, trg, src_mask, trg_mask)
    label = onehot(vocab, trg)

    src = embedding(src)
    trg = embedding(trg)

    mask = getmask(src_mask, trg_mask)

    enc = encoder(src)
    dec = decoder(trg, enc, mask)

    loss = logkldivergence(label, dec[:, 1:end-1, :], trg_mask[:, 1:end-1, :])
end
```


## Outline

```@contents
Pages = [
  "index.md",
  "basic.md",
  "stacks.md",
  "pretrain.md",
  "gpt.md",
  "bert.md",
  "datasets.md",
]
Depth = 2
```