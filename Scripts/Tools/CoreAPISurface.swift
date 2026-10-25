// Development-only parser: no SwiftSyntax dependency in a runtime package.
import Foundation
import SwiftParser
import SwiftSyntax

func unsupported(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
var methods: [[String: Any]] = []
func parameters(_ clause: FunctionParameterClauseSyntax) -> [[String: String]] {
    clause.parameters.map { ["label": $0.firstName.text, "name": ($0.secondName ?? $0.firstName).text, "type": $0.type.trimmedDescription] }
}
for file in CommandLine.arguments.dropFirst().sorted() {
    let source = try String(contentsOfFile: file, encoding: .utf8)
    let bytes = Array(source.utf8)
    let tree = Parser.parse(source: source)
    func record(_ declaration: DeclSyntax, scope: String, defaultPublic: Bool = false) {
        if let function = declaration.as(FunctionDeclSyntax.self) {
            let access = function.modifiers.map { $0.name.text }
            guard !access.contains("private"), !access.contains("internal"), !access.contains("package"),
                  defaultPublic || access.contains("public"), let body = function.body else { return }
            var signature = String(decoding: bytes[function.position.utf8Offset..<body.position.utf8Offset], as: UTF8.self)
            if !access.contains("public") { signature = "public " + signature.trimmingCharacters(in: .whitespacesAndNewlines) }
            methods.append(["scope":scope, "kind":"function", "name":function.name.text, "signature":signature,
                "async":function.signature.effectSpecifiers?.asyncSpecifier != nil,
                "throws":function.signature.effectSpecifiers?.throwsClause != nil,
                "parameters":parameters(function.signature.parameterClause)])
        } else if let initializer = declaration.as(InitializerDeclSyntax.self), scope == "AICustomProvider" {
            guard initializer.modifiers.contains(where: { $0.name.text == "public" }), let body = initializer.body else { return }
            // The explicit core resolver initializer is an adaptation hook, not a legacy overload.
            guard !initializer.signature.parameterClause.parameters.contains(where: { $0.firstName.text == "resolveDecisionModelID" }) else { return }
            methods.append(["scope":scope, "kind":"initializer", "name":"init", "signature":String(decoding:bytes[initializer.position.utf8Offset..<body.position.utf8Offset],as:UTF8.self).replacingOccurrences(of:"convenience ",with:""), "parameters":parameters(initializer.signature.parameterClause)])
        } else if let variable = declaration.as(VariableDeclSyntax.self), variable.modifiers.contains(where: { $0.name.text == "public" }), scope == "AICustomProvider" {
            for binding in variable.bindings {
                guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text, let type = binding.typeAnnotation?.type.trimmedDescription else { unsupported("Unsupported compatibility property in \(file)") }
                methods.append(["scope":scope, "kind":"property", "name":name, "type":type])
            }
        } else {
            let text = declaration.trimmedDescription
            if defaultPublic || text.hasPrefix("public ") { unsupported("Unsupported public compatibility declaration in \(file): \(text.prefix(100))") }
        }
    }
    for item in tree.statements {
        guard let decl = item.item.as(DeclSyntax.self) else { continue }
        if let ext = decl.as(ExtensionDeclSyntax.self), ["AI", "AIProviders"].contains(ext.extendedType.trimmedDescription) {
            for member in ext.memberBlock.members { record(member.decl, scope:ext.extendedType.trimmedDescription, defaultPublic:ext.modifiers.contains { $0.name.text == "public" }) }
        } else if let type = decl.as(EnumDeclSyntax.self), type.name.text == "AI" {
            for member in type.memberBlock.members { record(member.decl,scope:"AI") }
        } else if let type = decl.as(ClassDeclSyntax.self), type.name.text == "AICustomProvider" {
            for member in type.memberBlock.members { record(member.decl,scope:"AICustomProvider") }
        } else if let fn = decl.as(FunctionDeclSyntax.self), fn.name.text == "customProvider" {
            record(decl,scope:"global")
        }
    }
}
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: methods, options: [.sortedKeys]))
