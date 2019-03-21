---
title: "Java注释处理和创建构建器"
date: 2019-03-20T14:15:59+08:00
draft: false
---

> 本文由 [简悦 SimpRead](http://ksria.com/simpread/) 转码， 原文地址 http://www.baeldung.com/java-annotation-processing-builder

## **1.简介**

本文是**Java源代码级别注释处理的简介，**并提供了使用此技术在编译期间生成其他源文件的示例。

## **2.注释处理的应用**

源级注释处理首先出现在Java 5中。它是一种在编译阶段生成其他源文件的便捷技术。

源文件不必是Java文件 - 您可以根据源代码中的注释生成任何类型的描述，元数据，文档，资源或任何其他类型的文件。

注释处理在许多无处不在的Java库中被广泛使用，例如，在QueryDSL和JPA中生成元类，以使用Lombok库中的样板代码来扩充类。

需要注意的一件重要事情是**注释处理API的局限性 - 它只能用于生成新文件，而不能用于更改现有文件**。

值得注意的例外是[Lombok](https://projectlombok.org/)库，它使用注释处理作为引导机制，将自身包含在编译过程中，并通过一些内部编译器API修改AST。这种hacky技术与注释处理的预期目的无关，因此本文不讨论。

## **3.注释处理API**

注释处理在多轮中完成。每一轮都从编译器搜索源文件中的注释并选择适合这些注释的注释处理器开始。反过来，每个注释处理器在相应的源上被调用。

如果在此过程中生成了任何文件，则会以生成的文件作为输入启动另一轮。此过程将继续，直到在处理阶段没有生成新文件。

反过来，每个注释处理器在相应的源上被调用。如果在此过程中生成了任何文件，则会以生成的文件作为输入启动另一轮。此过程将继续，直到在处理阶段没有生成新文件。

注释处理API位于_javax.annotation.processing_包中。您必须实现的主要接口是_Processor_接口，它具有_AbstractProcessor_类形式的部分实现。这个类是我们要扩展的类，以创建我们自己的注释处理器。

## **4.设置项目**

为了演示注释处理的可能性，我们将开发一个简单的处理器，用于为带注释的类生成流畅的对象构建器。

我们将把项目分成两个Maven模块。其中之一，_注释处理器_模块，将包含处理器本身和注释，另一个_注释用户_模块将包含注释类。这是注释处理的典型用例。

_注释处理器_模块的设置如下。我们将使用Google的[自动服务](https://github.com/google/auto/tree/master/service)库来生成稍后将讨论的处理器元数据文件，以及针对Java 8源代码调整的_maven-compiler-plugin_。这些依赖项的版本将提取到属性部分。

可以在Maven Central存储库中找到最新版本的[自动服务](http://search.maven.org/#search%7Cgav%7C1%7Cg%3A%22com.google.auto.service%22%20AND%20a%3A%22auto-service%22)库和[maven-compiler-plugin](http://search.maven.org/#search%7Cgav%7C1%7Cg%3A%22org.apache.maven.plugins%22%20AND%20a%3A%22maven-compiler-plugin%22)：

```
<properties>
    <auto-service.version>1.0-rc2</auto-service.version>
    <maven-compiler-plugin.version>
      3.5.1
    </maven-compiler-plugin.version>
</properties>
 
<dependencies>
 
    <dependency>
        <groupId>com.google.auto.service</groupId>
        <artifactId>auto-service</artifactId>
        <version>${auto-service.version}</version>
        <scope>provided</scope>
    </dependency>
 
</dependencies>
 
<build>
    <plugins>
 
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>${maven-compiler-plugin.version}</version>
            <configuration>
                <source>1.8</source>
                <target>1.8</target>
            </configuration>
        </plugin>
 
    </plugins>
</build>
```

带有注释源的_注释用户_ Maven模块不需要任何特殊调整，除了在依赖项部分中添加对注释处理器模块的依赖：

```
<dependency>
    <groupId>com.baeldung</groupId>
    <artifactId>annotation-processing</artifactId>
    <version>1.0.0-SNAPSHOT</version>
</dependency>
```

## **5.定义注释**

假设我们的_annotation-user_模块中有一个简单的POJO类，它有几个字段：

```
public class Person {
 
    private int age;
 
    private String name;
 
    // getters and setters …
 
}
```

我们想要创建一个构建器帮助程序类，以更流畅地实例化_Person_类：

```
Person person = new PersonBuilder()
  .setAge(25)
  .setName("John")
  .build();
```
这个_PersonBuilder_类是一代的明显选择，因为它的结构完全由_Person_ setter方法定义。

让我们在_注释处理器_模块中为setter方法创建一个_@BuilderProperty_注释。它将允许我们为每个具有其setter方法注释的类生成_Builder_类：

```
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.SOURCE)
public @interface BuilderProperty {
}
```

带有_ElementType.METHOD_参数的_@Target_注释确保此注释只能放在方法上。

在_SOURCE_保留策略意味着该注释源处理期间唯一可用的，而不是在运行时可用。

具有使用_@BuilderProperty_注释注释的属性的_Person_类将如下所示：

```
public class Person {
 
    private int age;
 
    private String name;
 
    @BuilderProperty
    public void setAge(int age) {
        this.age = age;
    }
 
    @BuilderProperty
    public void setName(String name) {
        this.name = name;
    }
 
    // getters …
 
}
```

## **6.实现_处理器_**

### **6.1。创建_AbstractProcessor_子类**

我们将首先在_注释处理器_ Maven模块中扩展_AbstractProcessor_类。

首先，我们应该指定该处理器能够处理的注释，以及支持的源代码版本。这可以通过实施方法进行_getSupportedAnnotationTypes_和_getSupportedSourceVersion_的的_处理器_接口或通过注释你的类_@SupportedAnnotationTypes_和_@SupportedSourceVersion_注解。

所述_@AutoService_注释是的一部分_自动服务_库，并允许生成，这将在下面的章节进行说明处理器的元数据。

```
@SupportedAnnotationTypes(
  "com.baeldung.annotation.processor.BuilderProperty")
@SupportedSourceVersion(SourceVersion.RELEASE_8)
@AutoService(Processor.class)
public class BuilderProcessor extends AbstractProcessor {
 
    @Override
    public boolean process(Set<? extends TypeElement> annotations, 
      RoundEnvironment roundEnv) {
        return false;
    }
}
```

您不仅可以指定具体的注释类名称，还可以指定通配符，例如_“com.baeldung.annotation。*”_来处理_com.baeldung.annotation_包及其所有子包内的注释，甚至_“*”_来处理所有注释。

我们必须实现的单一方法是进行_处理的过程_方法。编译器会为包含匹配注释的每个源文件调用它。

注释作为第一个_Set <？_传递 _扩展TypeElement> annotations_参数，并将有关当前处理轮次的信息作为_RoundEnviroment roundEnv_参数传递。

如果注释处理器已处理了所有传递的注释，则返回_布尔_值应为_true_，并且您不希望它们传递到列表中的其他注释处理器。

### **6.2。收集数据**

我们的处理器还没有真正做任何有用的东西，所以让我们用代码填充它。

首先，我们需要遍历在类中找到的所有注释类型 - 在我们的示例中，_注释_集将具有与_@BuilderProperty_注释相对应的单个元素，即使此注释在源文件中多次出现也是如此。

尽管如此，为了完整起见，最好将_过程_方法实现为迭代循环：

```
@Override
public boolean process(Set<? extends TypeElement> annotations, 
  RoundEnvironment roundEnv) {
 
    for (TypeElement annotation : annotations) {
        Set<? extends Element> annotatedElements 
          = roundEnv.getElementsAnnotatedWith(annotation);
         
        // …
    }
 
    return true;
}
```

在此代码中，我们使用_RoundEnvironment_实例接收使用_@BuilderProperty_批注注释的所有元素。对于_Person_类，这些元素对应于_setName_和_setAge_方法。

_@BuilderProperty_注释的用户可能会错误地注释实际上不是setter的方法。setter方法名称应该以_set_开头，并且该方法应该接收一个参数。所以让我们将小麦与谷壳分开。

在下面的代码中，我们使用_Collectors.partitioningBy（）_收集器将带注释的方法拆分为两个集合：正确注释的setter和其他错误注释的方法：

```
Map<Boolean, List<Element>> annotatedMethods = annotatedElements.stream().collect(
  Collectors.partitioningBy(element ->
    ((ExecutableType) element.asType()).getParameterTypes().size() == 1
    && element.getSimpleName().toString().startsWith("set")));
 
List<Element> setters = annotatedMethods.get(true);
List<Element> otherMethods = annotatedMethods.get(false);
```

这里我们使用_Element.asType（）_方法接收_TypeMirror_类的实例，这使我们能够内省类型，即使我们只处于源处理阶段。

我们应该警告用户注释错误的方法，所以让我们使用可从_AbstractProcessor.processingEnv_ protected域访问的_Messager_实例。以下行将在源处理阶段为每个错误注释的元素输出错误：

```
otherMethods.forEach(element ->
  processingEnv.getMessager().printMessage(Diagnostic.Kind.ERROR,
    "@BuilderProperty must be applied to a setXxx method "
      + "with a single argument", element));
```

当然，如果正确的setter集合为空，则无法继续当前的类型元素集迭代：

```
if (setters.isEmpty()) {
    continue;
}
```

如果setter集合至少有一个元素，我们将使用它从封闭元素中获取完全限定的类名，如果setter方法看起来是源类本身：

```
String className = ((TypeElement) setters.get(0)
  .getEnclosingElement()).getQualifiedName().toString();

```

生成构建器类所需的最后一点信息是setter名称和参数类型名称之间的映射：

```
Map<String, String> setterMap = setters.stream().collect(Collectors.toMap(
    setter -> setter.getSimpleName().toString(),
    setter -> ((ExecutableType) setter.asType())
      .getParameterTypes().get(0).toString()
));
```

### **6.3。生成输出文件**

现在我们拥有生成构建器类所需的所有信息：源类的名称，所有setter名称及其参数类型。

要生成输出文件，我们将使用_AbstractProcessor.processingEnv_ protected属性中的对象再次提供的_Filer_实例：

```
JavaFileObject builderFile = processingEnv.getFiler()
  .createSourceFile(builderClassName);
try (PrintWriter out = new PrintWriter(builderFile.openWriter())) {
    // writing generated file to out …
}
```

下面提供了_writeBuilderFile_方法的完整代码。我们只需要为源类和构建器类计算包名，完全限定的构建器类名和简单类名。其余的代码非常简单。

```
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
 
    JavaFileObject builderFile = processingEnv.getFiler()
      .createSourceFile(builderClassName);
     
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
 
        setterMap.entrySet().forEach(setter -> {
            String methodName = setter.getKey();
            String argumentType = setter.getValue();
 
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
```

## **7.运行示例**

要查看代码生成的实际操作，您应该从公共父根编译两个模块，或者首先编译_注释处理器_模块，然后编译_注释用户_模块。

生成的_PersonBuilder_类可以在_annotation-user / target / generated-sources / annotations / com / baeldung / annotation / PersonBuilder.java_文件中找到，应该如下所示：

```
package com.baeldung.annotation;
 
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

## **8.注册处理器的其他方法**

要在编译阶段使用注释处理器，您还有其他几个选项，具体取决于您的使用案例和您使用的工具。

### **8.1。使用注释处理器工具**

该_贴切_工具是用于处理源文件一个特殊的命令行实用程序。它是Java 5的一部分，但是从Java 7开始，它被弃用以支持其他选项并在Java 8中完全删除。本文不讨论它。

### **8.2。使用编译器密钥**

该_-processor_编译器关键是一个标准的JDK设施，以增加编译器的源处理阶段，自己的注释处理器。

请注意，处理器本身和注释必须已在单独的编译中编译为类并出现在类路径中，因此您应该做的第一件事是：

```
javac com/baeldung/annotation/processor/BuilderProcessor
javac com/baeldung/annotation/processor/BuilderProperty
```

然后使用_-processor_键指定您刚刚编译的注释处理器类，对源进行实际编译：

```
javac -processor com.baeldung.annotation.processor.MyProcessor Person.java
```

要一次指定多个注释处理器，可以用逗号分隔它们的类名，如下所示：

```
javac -processor package1.Processor1,package2.Processor2 SourceFile.java
```

### **8.3。使用Maven**

的_行家-编译器插件_允许指定注释处理器作为其结构的一部分。

这是为编译器插件添加注释处理器的示例。您还可以使用_generatedSourcesDirectory_配置参数指定将生成的源放入的目录。

请注意，_BuilderProcessor_类应该已经编译，例如，从构建依赖项中的另一个jar导入：

```
<build>
    <plugins>
 
        <plugin>
            <groupId>org.apache.maven.plugins</groupId>
            <artifactId>maven-compiler-plugin</artifactId>
            <version>3.5.1</version>
            <configuration>
                <source>1.8</source>
                <target>1.8</target>
                <encoding>UTF-8</encoding>
                <generatedSourcesDirectory>${project.build.directory}
                  /generated-sources/</generatedSourcesDirectory>
                <annotationProcessors>
                    <annotationProcessor>
                        com.baeldung.annotation.processor.BuilderProcessor
                    </annotationProcessor>
                </annotationProcessors>
            </configuration>
        </plugin>
 
    </plugins>
</build>
```

### **8.4。将处理器Jar添加到Classpath**

您可以简单地将具有处理器类的特殊结构化jar添加到编译器的类路径中，而不是在编译器选项中指定注释处理器。

要自动获取它，编译器必须知道处理器类的名称。因此，您必须在_META-INF / services / javax.annotation.processing.Processor_文件中将其指定为处理器的完全限定类名：

```
com.baeldung.annotation.processor.BuilderProcessor
```

您还可以指定此jar中的多个处理器，通过用新行分隔它们来自动拾取：

```
package1.Processor1
package2.Processor2
package3.Processor3
```

如果您使用Maven构建此jar并尝试将此文件直接放入_src / main / resources / META-INF / services_目录中，您将遇到以下错误：

```
[ERROR] Bad service configuration file, or exception thrown while
constructing Processor object: javax.annotation.processing.Processor: 
Provider com.baeldung.annotation.processor.BuilderProcessor not found
```

这是因为当尚未编译_BuilderProcessor_文件时，编译器会尝试在模块本身的_源处理_阶段使用此文件。该文件必须放在另一个资源目录中，并在Maven构建的资源复制阶段复制到_META-INF / services_目录，或者在构建期间生成（甚至更好）。

以下部分中讨论的Google _自动服务_库允许使用简单的注释生成此文件。

### **8.5。使用Google _自动服务_库**

要自动生成注册文件，您可以使用Google _自动服务_库中的_@AutoService_注释，如下所示：

```
@AutoService(Processor.class)
public BuilderProcessor extends AbstractProcessor {
    // …
}
```
该注释本身由注释处理器从自动服务库处理。此处理器生成包含_BuilderProcessor_类名的_META-INF / services / javax.annotation.processing.Processor_文件。

## **9.结论**

在本文中，我们使用为POJO生成Builder类的示例演示了源级注释处理。我们还提供了几种在项目中注册注释处理器的替代方法。

该文章的源代码可[在GitHub上获得](https://github.com/eugenp/tutorials/tree/master/annotations)。