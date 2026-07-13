# Sound 性能基准

资料库微基准与日常单元测试分离，避免普通开发循环受 10,000 首数据影响。
在固定设备、无其他高负载任务时运行：

```sh
flutter test benchmark/library_performance_test.dart --reporter expanded
```

输出中的 `SOUND_PERF` 行是机器可读 JSON。当前覆盖：

- 1,000/10,000 首资料库记录到界面模型的刷新耗时；
- 搜索文档索引耗时；
- 后台 isolate 搜索耗时；
- 当前测试进程 RSS，仅作为同机相对参考；
- 歌词读取是否保持一次批量查询。

这些是 Debug/JIT 微基准，不代表用户实际帧率。启动首帧、滚动、封面解码、
平台内存与电量需要在 Profile 构建和固定真机上另行记录。
