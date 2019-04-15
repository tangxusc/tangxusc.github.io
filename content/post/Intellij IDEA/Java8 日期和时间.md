---
title: "Java8 日期和时间"
date: 2019-03-20T14:15:59+08:00
draft: false
categories:
- java
- date
tags:
- java
- date
keywords:
- java
- date
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://blog.csdn.net/a80596890555/article/details/58687444

如何正确处理时间
<!--more-->

![](http://7xvdkv.com1.z0.glb.clouddn.com/image/banner/DateTime_clock_zone.jpg)

现实生活的世界里，时间是不断向前的，如果向前追溯时间的起点，可能是宇宙出生时，又或是是宇宙出现之前，
但肯定是我们目前无法找到的，我们不知道现在距离时间原点的精确距离。所以我们要表示时间，
就需要人为定义一个原点。

原点被规定为，格林威治时间 (GMT)1970 年 1 月 1 日的午夜 为起点, 之于为啥是 GMT 时间，大概是因为本初子午线在那的原因吧。

## java 中的时间

如果你跟你朋友说：“我们 1484301456 一起去吃饭，别迟到！”，而你朋友能马上理解你说的时间，表示时间就会很简单，
只需要一个 long 值来表示原点的偏移量，这是个绝对时间，在世界范围内都适用。但实际上我们不能马上理解这串数字，
而且我们需要不同的时间单位来表示时间的跨度，比如一个季度是 3 个月，一个月有 30 天等。
你可以跟朋友约好 “明天这个时候再见面”, 你朋友很容易理解明天的意思，但要是没有’天’这个单位，
他就需要在那串数字上加上 86400(一天是 86400 秒)。

Java 三次引入处理时间的 API，JDK1.0 中包含了一个`Date`类，但大多数方法在 java1.1 引入`Calendear`类之后被弃用了。
它的实例都是可变的，而且它的 API 很难使用，比如月份是从 0 开始这种反人类的设置。

java8 引入的`java.time` API 已经纠正了之前的问题。它已经完全实现了`JSR310`规范。

## java8 时间 API 介绍及使用

在新的时间 API 中，`Instant`表示一个精确的时间点，`Duration`和`Period`表示两个时间点之间的时间量。
`LocalDate`表示日期，即 xx 年 xx 月 xx 日，即不包括时间也不带时区。`LocalTime`与`LocalDate`类似，
但只包含时间。`LocalDateTime`则包含日期和时间。`ZoneDateTime`表示一个带时区的时间。
`DateTimeFormatter`提供格式化和解析功能。下面详细的介绍使用方法。

### Instant

`Instant`表示一个精确的时间，时间数轴就是由无数个时间点组成，数轴的原点就是上面提
到的`1970-1-1 00:00:00`，`Instant`由两部分组成，一是从原点开始到指定时间点的秒数 s，
二是距离该秒数 s 的纳秒数。

![](http://7xvdkv.com1.z0.glb.clouddn.com/image/java8/time/timeline.png)

使用静态方法`Instant.now()`可以获取当前的时间点, **该方法默认使用的是 UTC(协调世界时——由原子钟提供) 时间**，可以使用`equeal` 和 `compareTo`来比较两个时间点的值。

计算某段代码执行时间可以使用下面的方式：

```java
Instant start = Instant.now();

doSomething();

Instant end = Instant.now();

Duration timeElapsed = Duration.between(start, end);
long millis = timeElapsed.toMillis();
System.out.println("millis = " + millis);

```

Duration 对象表示两个时间点之间的距离，通过类似`toMillis()` `toDays()` `getSeconds()`等方法，
得到各种时间单位表示的 Duration 对象。如果确实需要使用纳秒来做一些计算，可以调用`toNanos()`
获得一个 long 类型的值，该值表示距离原点的纳秒值。**大概 300 年的纳秒值会导致 long 值溢出**。

Duration 内部使用一个 long 类型来保存秒钟的值，使用一个 int 来保存纳秒的值，与 Instant 类似，
这个纳秒保存的是距离该秒钟的纳秒值.

Instant 与 Duration 都可以进行一些运算，来调整表示的时间，比如：`plus()` `minus` 方法，
表示增加或减少一段时间，`plusSeconds()` `minusSeconds()` `plusXxx()`等表示增加或减少相应时间单位的一段时间。

Duration 可以进行`multipliedBy()`乘法和`dividedBy()`除法运算。`negated()`做取反运算，即 1.2 秒取反后为 - 1.2 秒。

**非常重要的是**，Instant 和 Duration 类都是不可变的，他们的所有方法都返回一个新的实例。不可变类有很多优点：
不可变类使用起来不容易出错，其本质上是线程安全的，对象可以被自由的共享，而不用担心被某个方法修改。

### LocalDate(本地日期)

上面介绍的 Instant 是一个绝对的准确时间点，是人类不容易理解的时间，现在介绍人类使用的时间。

LocalDate 表示像 `2017-01-01`这样的日期。它包含有年份、月份、当月天数，它不不包含一天中的时间，
以及时区信息。由于上面的这些特点，所以 LocalDate 不能表示一个准确的时间点，即 Instant。

有很多时间的计算是不需要时区的，而且有一些情况下使用时区会导致一些问题，例如你在中国设置了一个
`2017-01-01 UT+8:00` 的放假提醒，但之后你去了美国，到了`2017-01-01 UT+8:00`时间时你收到了提醒，
但是此时美国还没到放假的时间。

API 的设计者推荐使用不带时区的时间，除非真的希望表示绝对的时间点。

可以使用静态方法`now()`和`of()`创建 LocalDate。`java.util.Date`使用 0 作为月份的开始，年份从 1990 年开始算起，
而新的 API 中完全是用生活中一样的方式来表示年和月份。

```java
//获取当前日期
LocalDate now = LocalDate.now();
//2017-01-01
LocalDate newYear = LocalDate.of(2017, 1, 1);

```

可以通过一些方法对日期做一些运算。

```java
//三天后
now.plusDays(3);
//一周后
now.plusWeeks(1)
//两天前 
now.minusDays(2)
//增加一个月不会出现2017-02-31 而是会返回该月的最后一个有效日期，即2017-02-28
LocalDate.of(2017, 1, 31).plusMonths(1)

LocalDate feb = LocalDate.of(2017, 2, 1);
//withXxx()表示以该日期为基础，修改年、月、日字段，并返回一个新的日期
//2019-2-1
feb.withYear(2019);
//2017-1-10
feb.withDayOfYear(10);
//2017-2-10
feb.withDayOfMonth(10);

```

上面讲过 Duration 表示的是 Instant 对应的时间段，LocalDate 对应的表示时间段的是 Period,
Period 内部使用三个 int 值分表表示年、月、日。
Duration 和 Period 都是 TemporalAmount 接口的实现，该接口表示时间量。

LocalDate 也可以增加或减少一段时间：

```java
//2019-02-01
feb.plus(Period.ofYears(2));
//2015-02-01
feb.minus(Period.ofYears(2);

```

使用 until 获得两个日期之间的 Period 对象

```java
//输出P9D，表示相差9天
feb.until(LocalDate.of(2017, 2, 10));//输出---> P9D
```

LocalDate 提供了一些测试方法：
`isBefore` `isAfter`比较两个 LocalDate，`isLeapYear`判断是否是闰年。

LocalDate 还提供了各种 getXxx 方法来返回所需要的数据，其中`getDayOfWeek()`返回`DayOfWeek`枚举。
`DayOfWeek`提供了`plus` `minus`来方便计算星期。

```java
//SUNDAY
LocalDate.of(2017, 1, 1).getDayOfWeek();
//TUESDAY
DayOfWeek.SUNDAY.plus(2);
```

除了 LocalDate，Java8 还提供了`Year` `MonthDay` `YearMonth`来表示部分日期，例如`MonthDay`可以表示 1 月 1 日。

### 日期校正器 TemporalAdjuster

如果想找到某个月的第一个周五，或是某个月的最后一天，像这样的日期就可以使用`TemporalAdjuster`来进行日期调整。
`TemporalAdjusters`提供一些静态方法，返回常用的`TemporalAdjuster`。

```java
//2017-02-03的下一个星期五(包含当天)  2017-03-03
LocalDate.of(2017, 2, 3).with(TemporalAdjusters.nextOrSame(DayOfWeek.FRIDAY));
//2017-02-03的下一个星期五(不包含当天)  2017-02-10
LocalDate.of(2017, 2, 3).with(TemporalAdjusters.next(DayOfWeek.FRIDAY));
//2月中的第3个星期五  2017-02-17
LocalDate.of(2017, 2, 3).with(TemporalAdjusters.dayOfWeekInMonth(3, DayOfWeek.FRIDAY));
//2月中的最后一个星期五  2017-02-24
LocalDate.of(2017, 2, 3).with(TemporalAdjusters.lastInMonth(DayOfWeek.FRIDAY));
//下个月的第一天
LocalDate.of(2017, 2, 3).with(TemporalAdjusters.firstDayOfNextMonth());
```

这是上面例子对应的当月日历

![](http://7xvdkv.com1.z0.glb.clouddn.com/image/java8/time/calendar20170223.jpg)

### LocalTime(本地时间)

LocalTime 表示一天中的某个时间，例如`18:00:00`。LocaTime 与 LocalDate 类似，他们也有相似的 API。

**需要注意的是：LocalTime 本身不关心是 AM 还是 PM，而是格式化程序来负责这个事情。**

### LocalDateTime(本地日期时间)

LocalDateTime 表示一个日期和时间，它适合用来存储确定时区的某个时间点。不适合跨时区的问题。

若需要处理跨时区的时间，需要使用 ZonedDateTime.

### ZonedDateTime(带时区的时间)

> 时区（Time Zone) 是地球上的区域使用同一个时间定义。1884 年在华盛顿召开国际经度会议时，
> 为了克服时间上的混乱，规定将全球划分为 24 个时区。
> 由于实用上常常 1 个国家，或 1 个省份同时跨着 2 个或更多时区，为了照顾到行政上的方便，
> 常将 1 个国家或 1 个省份划在一起。所以时区并不严格按南北直线来划分，而是按自然条件来划分。

Java 使用`ZoneId`来标识不同的时区.

```java
//获得所有可用的时区  size=590
ZoneId.getAvailableZoneIds();
//获取默认ZoneId对象
ZoneId defZoneId = ZoneId.systemDefault();
//获取指定时区的ZoneId对象
ZoneId shanghaiZoneId = ZoneId.of("Asia/Shanghai");
//ZoneId.SHORT_IDS返回一个Map<String, String> 是时区的简称与全称的映射。下面可以得到字符串 Asia/Shanghai
String shanghai = ZoneId.SHORT_IDS.get("CTT");

```

我在测试的时候一共有 590 个时区可用，但要知道，这个时区的个数不是固定的。

> IANA(Internet Assigned Numbers Authority，因特网拨号管理局) 维护着一份全球所有已知的时区数据库，
> 每年会更新几次，主要处理夏令时规则的改变。Java 使用了 IANA 的数据库。

#### 创建 ZonedDateTime

```java
//2017-01-20T17:35:20.885+08:00[Asia/Shanghai]
ZonedDateTime.now();
//2017-01-01T12:00+08:00[Asia/Shanghai]
ZonedDateTime.of(2017, 1, 1, 12, 0, 0, 0, ZoneId.of("Asia/Shanghai"));
//使用一个准确的时间点来创建ZonedDateTime，下面这个代码会得到当前的UTC时间，会比北京时间早8个小时
ZonedDateTime.ofInstant(Instant.now(), ZoneId.of("UTC"));
```

#### LocalDateTime 转换为 ZonedDateTime

```java
//atZone方法可以将LocalDateTime转换为ZonedDateTime，下面的方法将时区设置为UTC。
//假设现在的LocalDateTime是2017-01-20 17:55:00 转换后的时间为2017-01-20 17:55:00[UTC]
LocalDateTime.now().atZone(ZoneId.of("UTC"));
//使用静态of方法创建zonedDateTime
ZonedDateTime.of(LocalDateTime.now(), ZoneId.of("UTC"));
```

#### ZonedDateTime 的一些方法

ZonedDateTime 的许多方法与 LocalDateTime、LocalDate、LocalTime 类似，下面简单介绍几个方法的使用。

```java

ZonedDateTime utcDateTime = ZonedDateTime.of(2017, 1, 1, 12, 0, 0, 0, ZoneId.of("UTC"));//2017-01-01T12:00Z[UTC]
//withZoneSameLocal返回指定时区中的一个新ZonedDateTime，替换时区为指定时区，表示相同的本地时间的该时区时间。
utcDateTime.withZoneSameLocal(ZoneId.of("Asia/Shanghai"));//2017-01-01T12:00+08:00[Asia/Shanghai]
//withZoneSameInstant返回指定时区中的一个新ZonedDateTime，替换为指定时区，表示相同时间点的该时区时间。
utcDateTime.withZoneSameInstant(ZoneId.of("Asia/Shanghai"));//2017-01-01T20:00+08:00[Asia/Shanghai]

```

有一些国家和地区使用夏令时，处理起来需要注意，但在中国没有该问题，
需要注意的是使用`plus()`时要用`Period`对象表示的时间量，而不应该用`Duration`表示的时间量，
`Duration`不能处理夏令时。

```java
utcDateTime.plus(Duration.ofDays(7));//不能处理夏令时
utcDateTime.plus(Period.ofDays(7));//正确方式

```

### 格式化和解析 DateTimeFormatter

`DateTimeFormatter`是不可变类，而`SimpleDateFormat`是非线程安全的，是一个常见的坑。

#### 格式化

DateTimeFormatter 使用了三种格式化方法来打印日期和时间

*   **预定义的标准格式**

`DateTimeFormatter`预定义了一些格式，可以直接调用 format 方法

```java
//2017-01-01
DateTimeFormatter.ISO_LOCAL_DATE.format(LocalDate.of(2017, 1, 1))
//20170101
DateTimeFormatter.BASIC_ISO_DATE.format(LocalDate.of(2017, 1, 1));
//2017-01-01T09:10:00
DateTimeFormatter.ISO_LOCAL_DATE_TIME.format(LocalDateTime.of(2017, 1, 1, 9, 10, 0));

```

*   **语言环境相关的格式化风格**

根据当前操作系统语言环境，有`SHORET` `MEDIUM` `LONG` `FULL` 四种不同的风格来格式化。
可以通过`DateTimeFormatter`的静态方法`ofLocalizedDate` `ofLocalizedTime` `ofLocalizedDateTime`

```java
//2017年1月1日 星期日
DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).format(LocalDate.of(2017, 1, 1));
//上午09时10分00秒
DateTimeFormatter.ofLocalizedTime(FormatStyle.LONG).format(LocalTime.of(9, 10, 0));
//2017-2-27 22:32:03
DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM).format(LocalDateTime.now());
```

上面的方法都使用的是默认的语言环境，如果想改语言环境，需要使用`withLocale`方法来改变。

```java
//Feb 27, 2017 10:34:36 PM
DateTimeFormatter.ofLocalizedDateTime(FormatStyle.MEDIUM).withLocale(Locale.US).format(LocalDateTime.now());
```

*   **使用自定义模式格式化**

```java
//2017-02-27 22:48:52
DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss").format(LocalDateTime.now())
```

#### 解析

```java
//使用的ISO_LOCAL_DATE格式解析  2017-01-01
LocalDate.parse("2017-01-01");
//使用自定义格式解析  2017-01-01T08:08:08
LocalDateTime.parse("2017-01-01 08:08:08", DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));

```

### 遗留代码相互操作

`Instant` 类似于`java.util.Date`

`ZonedDateTime`类似于`java.util.GregorianCalendar`

```java
//Date --> Instant
Instant timestamp = new Date().toInstant();
//Instant --> Date
Date.from(Instant.now());

//GregorianCalendar --> ZonedDateTime
new GregorianCalendar().toZonedDateTime();
//ZonedDateTime --> GregorianCalendar
GregorianCalendar.from(zonedDateTime);

//2017-02-27T21:16:13.647
LocalDateTime.ofInstant(timestamp, ZoneId.of(ZoneId.SHORT_IDS.get("PST")));

//Calendar --> Instant
//2017-02-28T05:16:13.656Z
Calendar.getInstance().toInstant();

```
