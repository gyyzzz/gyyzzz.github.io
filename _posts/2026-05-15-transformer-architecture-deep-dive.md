---
title: "深入理解Transformer架构：从注意力机制到GPT"
layout: post
category: llm-dynamics
date: 2026-05-15
---

Transformer架构自2017年提出以来，已成为现代大语言模型的基石。本文将从注意力机制入手，深入剖析Transformer的核心原理。

## 注意力机制的本质

注意力机制的核心思想是：让模型能够关注输入序列中的重要部分。数学表达式为：

```
Attention(Q, K, V) = softmax(QK^T / √d_k) V
```

其中：
- Q (Query)：查询向量
- K (Key)：键向量
- V (Value)：值向量
- d_k：键向量的维度

## 多头注意力

多头注意力通过并行运行多个注意力头，使模型能够同时关注不同位置的不同表示子空间：

```python
class MultiHeadAttention(nn.Module):
    def __init__(self, d_model, num_heads):
        super().__init__()
        self.d_model = d_model
        self.num_heads = num_heads
        self.head_dim = d_model // num_heads
        
        self.q_linear = nn.Linear(d_model, d_model)
        self.k_linear = nn.Linear(d_model, d_model)
        self.v_linear = nn.Linear(d_model, d_model)
        self.out_linear = nn.Linear(d_model, d_model)
    
    def forward(self, q, k, v, mask=None):
        batch_size = q.size(0)
        
        # Linear projections
        q = self.q_linear(q).view(batch_size, -1, self.num_heads, self.head_dim).transpose(1, 2)
        k = self.k_linear(k).view(batch_size, -1, self.num_heads, self.head_dim).transpose(1, 2)
        v = self.v_linear(v).view(batch_size, -1, self.num_heads, self.head_dim).transpose(1, 2)
        
        # Attention
        scores = torch.matmul(q, k.transpose(-2, -1)) / math.sqrt(self.head_dim)
        if mask is not None:
            scores = scores.masked_fill(mask == 0, -1e9)
        attention = F.softmax(scores, dim=-1)
        output = torch.matmul(attention, v)
        
        # Concat and linear
        output = output.transpose(1, 2).contiguous().view(batch_size, -1, self.d_model)
        return self.out_linear(output)
```

## 位置编码

由于Transformer没有循环结构，需要位置编码来注入位置信息：

```
PE(pos, 2i) = sin(pos / 10000^(2i/d_model))
PE(pos, 2i+1) = cos(pos / 10000^(2i/d_model))
```

这种编码方式的优势在于：
1. 位置信息是确定性的，无需学习
2. 可以泛化到任意长度序列
3. 相对位置可以通过线性变换得到

## 从Transformer到GPT

GPT（Generative Pre-trained Transformer）系列采用Transformer的Decoder部分：

1. **GPT-1**：证明了预训练+微调的有效性
2. **GPT-2**：扩大规模，展示Zero-shot能力
3. **GPT-3**：175B参数，展示Few-shot和In-context学习能力
4. **GPT-4**：多模态能力，更强的推理能力

## 实践建议

在实际应用中，需要注意：

- **显存优化**：使用Flash Attention、梯度检查点等技术
- **推理加速**：KV Cache、投机解码、量化
- **训练稳定性**：LayerNorm的位置、学习率预热

## 总结

Transformer的成功在于其简洁而强大的设计。理解这些基础原理，对于开发和优化LLM应用至关重要。下一期我们将深入探讨RAG（检索增强生成）的实现细节。

---

*参考资料：*
- [Attention Is All You Need](https://arxiv.org/abs/1706.03762)
- [Language Models are Few-Shot Learners](https://arxiv.org/abs/2005.14165)