> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 https://www.cnblogs.com/throwable/p/9139908.html

# [插件化注解处理 API(Pluggable Annotation Processing API)](https://www.cnblogs.com/throwable/p/9139908.html)

# Java 奇技淫巧 - 插件化注解处理 API(Pluggable Annotation Processing API)

# 参考资料

*   [JDK6 的新特性之六: 插入式注解处理 API(Pluggable Annotation Processing API)](https://blog.csdn.net/Chinajash/article/details/1471081)
*   [Java Annotation Processing and Creating a Builder](http://www.baeldung.com/java-annotation-processing-builder)

# 简介

插件化注解处理 (Pluggable Annotation Processing)API[JSR 269](http://jcp.org/en/jsr/detail?id=269) 提供一套标准 API 来处理 Annotations[JSR 175](http://jcp.org/en/jsr/detail?id=175), 实际上 JSR 269 不仅仅用来处理 Annotation，我觉得更强大的功能是它建立了 Java 语言本身的一个模型, 它把 method、package、constructor、type、variable、enum、annotation 等 Java 语言元素映射为 Types 和 Elements，从而将 Java 语言的语义映射成为对象，我们可以在 javax.lang.model 包下面可以看到这些类。所以我们可以利用 JSR 269 提供的 API 来构建一个功能丰富的元编程 (metaprogramming) 环境。JSR 269 用 Annotation Processor 在编译期间而不是运行期间处理 Annotation, Annotation Processor 相当于编译器的一个插件, 所以称为插入式注解处理. 如果 Annotation Processor 处理 Annotation 时 (执行 process 方法) 产生了新的 Java 代码，编译器会再调用一次 Annotation Processor，如果第二次处理还有新代码产生，就会接着调用 Annotation Processor，直到没有新代码产生为止。每执行一次 process()方法被称为一个 "round"，这样整个 Annotation processing 过程可以看作是一个 round 的序列。JSR 269 主要被设计成为针对 Tools 或者容器的 API。这个特性虽然在 JavaSE 6 已经存在，但是很少人知道它的存在。下一篇介绍的 **Java 奇技淫巧 - lombok** 就是使用这个特性实现编译期的代码插入的。另外，如果没有猜错，像 IDEA 在编写代码时候的标记语法错误的红色下划线也是通过这个特性实现的。KAPT(Annotation Processing for Kotlin)，也就是 Kotlin 的编译也是通过此特性的。

Pluggable Annotation Processing API 的核心是 Annotation Processor 即注解处理器，一般需要继承抽象类`javax.annotation.processing.AbstractProcessor`。注意，与运行时注解`RetentionPolicy.RUNTIME`不同，注解处理器只会处理编译期注解，也就是`RetentionPolicy.SOURCE`的注解类型，处理的阶段位于 Java 代码编译期间。

# 使用步骤

插件化注解处理 API 的使用步骤大概如下：

*   1、自定义一个 Annotation Processor，需要继承`javax.annotation.processing.AbstractProcessor`，并覆写 process 方法。
*   2、自定义一个注解，注解的元注解需要指定`@Retention(RetentionPolicy.SOURCE)`。
*   3、需要在声明的自定义 Annotation Processor 中使用`javax.annotation.processing.SupportedAnnotationTypes`指定在第 2 步创建的注解类型的名称 (注意需要全类名，"包名. 注解类型名称"，否则会不生效)。
*   4、需要在声明的自定义 Annotation Processor 中使用`javax.annotation.processing.SupportedSourceVersion`指定编译版本。
*   5、可选操作，可以通在声明的自定义 Annotation Processor 中使用`javax.annotation.processing.SupportedOptions`指定编译参数。

# 实战例子

## 基础

下面我们模仿一下测试框架 Junit 里面的 @Test 注解，在运行时通过 Annotation Processor 获取到使用了自定义的 @Test 注解对应的方法的信息。因为如果想要动态修改一个类或者方法的代码内容，需要使用到字节码修改工具例如 ASM 等，这些操作过于深入，日后再谈。先定义一个注解：

```
package club.throwable.processor;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * @author throwable
 * @version v1.0
 * @description
 * @since 2018/5/27 11:18
 */
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.SOURCE)
public @interface Test {

}
```

定义一个注解处理器：

```
@SupportedAnnotationTypes(value = {"club.throwable.processor.Test"})
@SupportedSourceVersion(value = SourceVersion.RELEASE_8)
public class AnnotationProcessor extends AbstractProcessor {

    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        System.out.println("Log in AnnotationProcessor.process");
        for (TypeElement typeElement : annotations) {
            System.out.println(typeElement);
        }
        System.out.println(roundEnv);
        return true;
    }
}
```

编写一个主类：

```
public class Main {

    public static void main(String[] args) throws Exception{
        System.out.println("success");
        test();
    }

    @Test(value = "method is test")
    public static void test()throws Exception{

    }
}
```

接着需要指定 Processor，如果使用 IDEA 的话，Compiler->Annotation Processors 中的 Enable annotation processing 必须勾选。然后可以通过下面几种方式指定指定 Processor。

*   1、直接使用编译参数指定，例如：javac -processor club.throwable.processor.AnnotationProcessor Main.java。
*   2、通过服务注册指定，就是 META-INF/services/javax.annotation.processing.Processor 文件中添加 club.throwable.processor.AnnotationProcessor。
*   3、通过 Maven 的编译插件的配置指定如下：

```
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.5.1</version>
            <configuration>
                <source>1.8</source>
                <target>1.8</target>
                <encoding>UTF-8</encoding>
                <annotationProcessors>
                    <annotationProcessor>
                        club.throwable.processor.AnnotationProcessor
                    </annotationProcessor>
                </annotationProcessors>
            </configuration>
        </plugin>
```

值得注意的是，以上三点生效的前提是 club.throwable.processor.AnnotationProcessor 已经被编译过，否则编译的时候就会报错：

```
[ERROR] Bad service configuration file, or exception thrown while
constructing Processor object: javax.annotation.processing.Processor: 
Provider club.throwable.processor.AnnotationProcessor not found
```

解决方法有两种，第一种是提前使用命令或者 IDEA 右键 club.throwable.processor.AnnotationProcessor 对它进行编译；第二种是把 club.throwable.processor.AnnotationProcessor 放到一个独立的 Jar 包引入。我在这里使用第一种方式解决。

最后，使用 Maven 命令 mvn compile 进行编译。输出如下：

```
Log in AnnotationProcessor.process
[errorRaised=false, rootElements=[club.throwable.processor.Test,club.throwable.processor.Main, club.throwable.processor.AnnotationProcessor, processingOver=false]
Log in AnnotationProcessor.process
[errorRaised=false, rootElements=[], processingOver=false]
Log in AnnotationProcessor.process
[errorRaised=false, rootElements=[], processingOver=true]
```

可见编译期间 AnnotationProcessor 生效了。

## 进阶

下面是一个例子直接修改类的代码，为实体类的 Setter 方法对应的属性生成一个 Builder 类，也就是原来的类如下：

```
public class Person {

    private Integer age;
    private String name;

    public Integer getAge() {
        return age;
    }

    @Builder
    public void setAge(Integer age) {
        this.age = age;
    }

    public String getName() {
        return name;
    }

    @Builder
    public void setName(String name) {
        this.name = name;
    }
}
```

生成的 Builder 类如下：

```
public class PersonBuilder {

    private Person object = new Person();

    public Person build() {
        return object;
    }

    public PersonBuilder setName(java.lang.String value) {
        object.setName(value);
        return this;
    }

    public PersonBuilder setAge(int value) {
        object.setAge(value);
        return this;
    }
}
```

自定义的注解如下：

```
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.SOURCE)
public @interface Builder {

}
```

自定义的注解处理器如下：

```
import javax.annotation.processing.AbstractProcessor;
import javax.annotation.processing.RoundEnvironment;
import javax.annotation.processing.SupportedAnnotationTypes;
import javax.annotation.processing.SupportedSourceVersion;
import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.TypeElement;
import javax.lang.model.type.ExecutableType;
import javax.tools.Diagnostic;
import javax.tools.JavaFileObject;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * @author throwable
 * @version v1.0
 * @description
 * @since 2018/5/27 11:21
 */
@SupportedAnnotationTypes(value = {"club.throwable.processor.builder.Builder"})
@SupportedSourceVersion(value = SourceVersion.RELEASE_8)
public class BuilderProcessor extends AbstractProcessor {

    @Override
    public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
        for (TypeElement typeElement : annotations) {
            Set<? extends Element> annotatedElements = roundEnv.getElementsAnnotatedWith(typeElement);
            Map<Boolean, List<Element>> annotatedMethods
                    = annotatedElements.stream().collect(Collectors.partitioningBy(
                    element -> ((ExecutableType) element.asType()).getParameterTypes().size() == 1
                            && element.getSimpleName().toString().startsWith("set")));
            List<Element> setters = annotatedMethods.get(true);
            List<Element> otherMethods = annotatedMethods.get(false);
            otherMethods.forEach(element ->
                    processingEnv.getMessager().printMessage(Diagnostic.Kind.ERROR,
                            "@Builder must be applied to a setXxx method "
                                    + "with a single argument", element));
            Map<String, String> setterMap = setters.stream().collect(Collectors.toMap(
                    setter -> setter.getSimpleName().toString(),
                    setter -> ((ExecutableType) setter.asType())
                            .getParameterTypes().get(0).toString()
            ));
            String className = ((TypeElement) setters.get(0)
                    .getEnclosingElement()).getQualifiedName().toString();
            try {
                writeBuilderFile(className, setterMap);
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        return true;
    }

    private void writeBuilderFile(
            String className, Map<String, String> setterMap)
            throws IOException {
        String packageName = null;
        int lastDot = className.lastIndexOf('.');
        if (lastDot > 0) {
            packageName = className.substring(0, lastDot);
        }
        String simpleClassName = className.substring(lastDot + 1);
        String builderClassName = className + "Builder";
        String builderSimpleClassName = builderClassName
                .substring(lastDot + 1);

        JavaFileObject builderFile = processingEnv.getFiler().createSourceFile(builderClassName);

        try (PrintWriter out = new PrintWriter(builderFile.openWriter())) {

            if (packageName != null) {
                out.print("package ");
                out.print(packageName);
                out.println(";");
                out.println();
            }
            out.print("public class ");
            out.print(builderSimpleClassName);
            out.println(" {");
            out.println();
            out.print("    private ");
            out.print(simpleClassName);
            out.print(" object = new ");
            out.print(simpleClassName);
            out.println("();");
            out.println();
            out.print("    public ");
            out.print(simpleClassName);
            out.println(" build() {");
            out.println("        return object;");
            out.println("    }");
            out.println();
            setterMap.forEach((methodName, argumentType) -> {
                out.print("    public ");
                out.print(builderSimpleClassName);
                out.print(" ");
                out.print(methodName);

                out.print("(");

                out.print(argumentType);
                out.println(" value) {");
                out.print("        object.");
                out.print(methodName);
                out.println("(value);");
                out.println("        return this;");
                out.println("    }");
                out.println();
            });
            out.println("}");
        }
    }
}
```

主类如下：

```
public class Main {

    public static void main(String[] args) throws Exception{
      //PersonBuilder在编译之后才会生成，这里需要编译后才能这样写
      Person person  = new PersonBuilder().setAge(25).setName("doge").build();
    }
}
```

先手动编译 BuilderProcessor，然后在 META-INF/services/javax.annotation.processing.Processor 文件中添加`club.throwable.processor.builder.BuilderProcessor`，最后执行 Maven 命令 mvn compile 进行编译。

编译后控制台输出:

```
[errorRaised=false, rootElements=[club.throwable.processor.builder.PersonBuilder], processingOver=false]
```

编译成功之后，target/classes 包下面的 club.throwable.processor.builder 子包路径中会新增了一个类`PersonBuilder`：

```
package club.throwable.processor.builder;

public class PersonBuilder {
    private Person object = new Person();

    public PersonBuilder() {
    }

    public Person build() {
        return this.object;
    }

    public PersonBuilder setName(String value) {
        this.object.setName(value);
        return this;
    }

    public PersonBuilder setAge(Integer value) {
        this.object.setAge(value);
        return this;
    }
}
```

这个类就是编译期新增的。在这个例子中，编译期新增的类貌似没有什么作用。但是，如果像 lombok 那样对原来的实体类添加新的方法，那样的话就比较有用了。因为些类或者方法是编译期添加的，因此在代码中直接使用会标红。因此，lombok 提供了 IDEA 或者 eclipse 的插件，插件的功能的实现估计也是用了插件式注解处理 API。

# 小结

我在了解 Pluggable Annotation Processing API 的时候，通过搜索引擎搜索到的几乎都是安卓开发通过插件式注解处理 API 编译期动态添加代码等等的内容，可见此功能的使用还是比较广泛的。可能在文中的实战例子并不能体现 Pluggable Annotation Processing API 功能的强大，因此有时间可以基于此功能编写一些代码生成插件，例如下一篇将要介绍的 lombok。

（本文完）