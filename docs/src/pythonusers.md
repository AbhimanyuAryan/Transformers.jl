# Tutorial for huggingface users from Python

Text classification is a common NLP task that assigns a label or class to text. Some of the largest companies run text classification in production for a wide range of practical applications. One of the most popular forms of text classification is sentiment analysis, which assigns a label like 🙂 positive, 🙁 negative, or 😐 neutral to a sequence of text.

This guide will show you how to:

1. Finetune [DistilBERT](https://huggingface.co/distilbert-base-uncased) on the [IMDb](https://huggingface.co/datasets/imdb) dataset to determine whether a movie review is positive or negative.
2. Use your finetuned model for inference.

## Installation

First, install the `Transformers.jl` package by running the following command:

```julia
using Pkg
Pkg.add("Transformers")
```

Secondly, install the `HuggingFaceDatasets.jl` package by running the following command:

```julia
using Pkg
Pkg.add("HuggingFaceDatasets")
```

The next step is to load a DistilBERT tokenizer to preprocess the `text` field:

```julia
using Transformers
using Transformers.TextEncoders
using Transformers.HuggingFace

tokenizer = HuggingFace.load_tokenizer("distilbert-base-uncased")
```

## Load dataset


### Start by loading the IMDb dataset from the 🤗 Datasets library:

```julia
train_data = load_dataset("imdb", split="train").with_format("julia")
test_data = load_dataset("imdb", split="test").with_format("julia")

train_data[1]
```




source: https://huggingface.co/docs/transformers/en/tasks/sequence_classification