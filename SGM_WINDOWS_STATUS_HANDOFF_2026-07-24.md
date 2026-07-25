# SGM Windows 本地化重制 — 现状交底文档 (2026-07-24)

给你在另一个Claude窗口做规划用。这份文档尽量客观列事实（做了什么、在哪、
已知什么问题），不替你做决定。

## 1. 项目背景

出发点：`APP_MEMORY_HANDOFF_FOR_SGM_REDESIGN_2026-07-20.md`（架构决策
文档）。核心方向：SGM本地权威化——现金水位、存款/找零、残值处理这些原来
依赖云端/app的判断，改成SGM本地就能独立正确运作；云端(Supabase)从"权威
数据源"降级为"镜像/审计用途"；订单创建仍然只能通过app发起（反欺诈规则，
本次没有改变）。

按你当时定的优先级：
1. 现金水位（Livelli cassa）本地权威化
2. 存款/找零流程（incasso）完善
3. 残值/二次确认流程完善

以上三项这次会话里都做完了（细节见第3节）。另外还接了一个新分支：新版
"SGM Connect" app的BLE协议对接（跟上面3项优先级是平行的一条线，细节见
第5节，目前卡在等app团队回复）。

## 2. 触屏后台入口地图

**进入方式**：主屏幕右上角连续点3下 → 弹PIN → 输入PIN进管理菜单
（本地万能PIN `111111`，或角色PIN commesso/direttore/supremo）。

管理菜单是按角色显示不同瓷砖(tile)，代码在
`src/sgm/ui/display.py` 的 `_admin_menu_items()`：

| 角色门槛 | key | 显示名 | 内容 |
|---|---|---|---|
| 所有角色 | `stato` | Stato macchina | 硬件状态 + 现金水位数字展示(本次新增) |
| 所有角色 | `incasso` | Deposita incasso | 存款流程(本次改造：理论金额录入→收款→对账) |
| direttore/supremo | `refill` | Carico cassette | （占位，未改动） |
| direttore/supremo | `chiusura` | Contabilità | （占位，未改动） |
| direttore/supremo | `svuota` | Svuotamento | （占位，未改动） |
| direttore/supremo | `tema` | Tema schermo | 换主题 |
| supremo | `test` | Test hardware | （占位，未改动） |
| supremo | `cdm` | Test CDM6240N | 5钱箱独立测试面板 |
| supremo | `ble` | BLE (App) | 旧协议BLE开关/Token配置 |
| supremo | `setup` | Impostazioni macchina | 身份/硬件/云端配置向导 |
| supremo | `config` | Configurazione | （占位，未改动） |
| supremo | `log` | Registro eventi | （占位，未改动） |

**不是菜单入口、是情况触发的界面**（没有真实残值/含糊清点发生时看不到，
不能主动点进去）：
- 残值处理2×2按钮（自动出钞/关闭人工支付/取消无现金移动/挂起）
- 纸币(F53)清点确认界面
- 硬币(hopper)清点确认界面（本次新增，跟纸币界面分开）

## 3. 本次会话完成的功能清单

### 3.1 现金水位本地权威化
- 修复了`livello_attuale`为NULL时被静默当成0处理的真实事故根因bug
  （`src/sgm/services/supabase_client.py`）。
- 本地SQLite账本(`cash_devices`/`cash_unit_config`/`cash_unit_snapshots`,
  `src/sgm/services/local_ledger.py`)接入健康检查读取路径
  (`task_health_check`, `src/sgm/main.py`)，每次真实(非mock)读到钱箱状态
  就落一条本地快照，本地成为权威数据源。
- 触屏"Stato macchina"页新增5个钱箱的数字展示卡片（`_render_cash_levels_grid`,
  `display.py:2971`）——**这块你反馈的字体重叠问题，我复查代码确认了
  具体bug，见第4节**。
- 现金水位表加了`sync_status`/`synced_at`/`source`同步元数据字段，云端
  `kiosk_livelli_cash`变成本地数据的被动镜像（有专门的后台同步任务，
  匹配真机出钞用的同一套钱箱编号"cass_1".."cass_5"，云端对应行不存在
  就跳过、绝不新建）。

### 3.2 存款/找零流程完善
- 修复了"当日已存"金额计算漏算硬币的字段名不匹配bug。
- 修复了硬币/找零含糊情况被错误路由进纸币(F53)清点界面的bug，新增独立
  的硬币清点界面(`_render_hopper_conteggio`)。
- 存款流程新增"理论金额本地录入"步骤：点"Deposita incasso"不再直接开始
  收纸币，先进一个数字键盘录入理论金额的界面(`_render_deposito_teorico_input`,
  可跳过)，走跟app远程发起存款完全相同的SGM权威计算逻辑。
- 存款完成后新增"对账"界面(`_render_deposito_riconciliazione`)，显示
  理论/现金合计/差额，差额超±1欧要求操作员显式确认才能返回待机——**这
  块也在第4节复查里发现了字体重叠风险**。

### 3.3 残值/二次确认流程完善
- 触屏补齐了"取消·确认无现金移动"(void)和"挂起稍后处理"(suspend)两个
  按钮，界面从2按钮改成2×2网格。
- 角色门禁按动作可逆性区分：硬件已验证/可逆的动作(自动出钞、挂起)PIN
  门槛较低(commesso+)；纯操作员口头确认/终结性动作(关闭为人工、取消)
  门槛较高(direttore/supremo)。

### 3.4 CDM6240N硬件测试面板
- 5个钱箱独立测试按钮(之前"混合测试"只测得到3个的bug已修)。
- Reset按钮解锁逻辑修复(Reset是解除厂商安全锁的唯一手段，之前被
  `available`门禁卡死打不开)。
- native host/bridge层的厂商错误文字说明完整链路打通。

### 3.5 BLE — "SGM Connect" app对接（新分支，见第5节）
- hello握手 + INFO只读特征值已实现并打包发布。
- 角色/PIN本地化(bootstrap_sala/login/list_roles等)还没做——app那边
  还没定字段规格，做了容易返工。
- **目前卡点**：这台机器的蓝牙网卡一次只能真正广播一个GATT服务，旧协议
  和新协议的服务不能同时被app扫描发现。已经排查出根因、写了提议方案
  发给app团队，等他们确认是否愿意在app侧加降级扫描逻辑。

## 4. 你反馈的问题，我复查代码确认的情况

### 4.1 字体重叠 —— 已确认根因，至少2处具体bug

`_draw_text()`的对齐规则(`display.py:3846`)：`align="center"`时y是文字
**垂直中心**；`align="left"/"right"`时y是文字**顶部**。这次新增的几个
界面里，多处把"card"字体(52px，本来是给单独一个大数字用的)跟别的文字
挤在了间距只有50-60px的几行里，必然视觉重叠：

- **`_render_cash_levels_grid`** (`display.py:2971`)：每个钱箱卡片只有
  72px高，里面塞了3行——标签(small字体,居中y=y0+14) / 数值("card"字体
  52px！居中y=y0+32) / 更新时间(small字体,居中y=y0+56)。52px的数值几乎
  盖住了上下两行文字的位置。
- **`_render_deposito_riconciliazione`** (`display.py`，存款对账界面)：
  "理论"/"现金合计"两行用52px字体，行间距只有60px（52px字体本身几乎
  撑满这个间距，没留视觉安全边距）；下面的"分项说明"文字(y=378)跟上面
  "现金合计"数值(52px, y=340起)在垂直方向也是压线甚至重叠，具体会不会
  肉眼可见取决于金额数字长度和字体实际渲染高度。
- 这两处是我复查确认到的，**没有逐屏全部审查**——你说的"很多"页面，
  不排除还有同样"52px大字体+行距不够"这个模式在别处重复出现（这是这次
  新加界面里反复用的一个排版套路，一旦密度高的地方就容易出这个问题）。

### 4.2 "现金化的页面都是不可以设置的"

我没能完全确定你具体指哪些页面/哪种"不可设置"，复查了目前能编辑现金
硬件参数的入口，供你判断是不是这个：

- "Impostazioni macchina"向导 → 硬件选择 → 编辑某个设备(F53/CDM6240N)：
  **可以**改 启用开关/型号/串口/波特率，也有"测试"按钮(`display.py:3595`
  `_render_setup_hw_edit`)。
- 但是**钱箱级别的参数**——每个钱箱对应的面额、容量上限、低位预警阈值
  (`denom_cent`/`nominal_capacity`/`low_threshold`，`cash_unit_config`表
  里的字段)——**没有任何触屏入口能改**，CDM6240N这边这些值是写死在
  `CDM6240N_CASSETTES`常量里(`local_ledger.py`)，F53(旧机型)是从环境变量
  `F53_CASSETTES`解析的，都不是"点触屏就能改"的东西。
- "Stato macchina"的现金水位展示页是纯只读展示，本来设计上就没打算做成
  可编辑（数字来自硬件实际读数，不是人工输入的）。

如果你说的是钱箱面额/容量这块，那是一个真实的功能缺口（不是bug，是
从来没做过）；如果是别的页面，麻烦下次告诉我具体是哪个入口点进去之后
发现改不了。

## 5. 技术架构 / 关键文件地图

```
src/sgm/
  main.py                          异步应用主体，硬件轮询/存款流程/残值处理
                                    等核心状态机都在这
  ui/display.py                    pygame触屏UI，~3700+行，所有页面渲染+
                                    触摸处理都在这一个文件里
  services/
    local_ledger.py                本地SQLite账本：现金操作状态机 + CDM6240N
                                    钱箱快照 + BLE会话表，是"本地权威"的核心
    supabase_client.py              云端镜像写入(现金水位/存款/事件等)
    ble_server.py                   BLE GATT外围设备(两个service并存：旧协议
                                    + SGM Connect)
    connect_ble_protocol.py         SGM Connect协议(目前只有hello)
    ble_protocol.py                 旧协议(TITO/Snai本地支付完整状态机)
    local_ledger_sync.py            本地账本→云端镜像的后台同步worker
  drivers/grg_cdm6240n.py           CDM6240N硬件驱动(经native host/bridge)
  setup/
    schema.py / config_store.py     机器配置(MachineConfig)定义与JSON持久化
    technician_auth.py              技师PIN本地哈希存储(pbkdf2)，如果以后要做
                                    "角色本地化"，这是现成可复用的范式
    wizard.py                       Impostazioni向导的UI无关逻辑层

packaging/windows/sgm_windows.spec  PyInstaller打包配置
C:\ProgramData\SGM\                 真机运行时数据目录(config.json/日志/
                                    本地SQLite数据库)
```

打包产物：`C:\Users\User\Documents\Codex\2026-07-22\zhe\outputs\`，最新是
`SGM-Windows-CDM6240N-Management-20260724-v6.zip`（每轮改动都会重新打包，
文件名递增版本号，`FIX_NOTES.txt`里有每轮的中文变更记录）。

## 6. 未决事项

- **BLE discovery卡点**：见第3.5节，等app团队回复是否愿意加降级扫描
  逻辑（提议文档在桌面`BLE_DISCOVERY_PROPOSAL_2026-07-24.md`）。
- **字体重叠**：已确认根因但未修复，等你规划完看要不要现在改还是先攒
  一批一起改。
- **钱箱级参数编辑**：功能缺口，不确定是否是你想要的"可设置"。

## 7. 一些可以讨论的角度（不代表建议，供参考）

- 现在所有UI都是pygame手写像素坐标(`x, y, w, h`硬编码)，没有布局引擎/
  没有自动换行或碰撞检测——密度越高的页面（多行数字堆叠的那种）越容易
  出现这次这种重叠问题。要不要在改具体bug之前，先定一套"最小行高/字体
  搭配"的约定，还是走一屏一屏单独调坐标？
- 是否要对已经上线的这几个新界面做一次系统性的坐标复查（不只是我这次
  发现的2处），还是先按你实际用起来遇到的具体页面反馈来改？
