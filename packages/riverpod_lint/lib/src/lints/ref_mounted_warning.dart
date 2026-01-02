import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:riverpod_analyzer_utils/riverpod_analyzer_utils.dart';

class RefMountedWarning extends AnalysisRule {
  RefMountedWarning()
    : super(name: code.name, description: code.problemMessage);

  static const code = LintCode(
    'ref_mounted_warning',
    'While updating state make sure to check if the ref is mounted.',
  );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addAssignmentExpression(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide;

    // Check if the left side is 'state'
    var isState = false;
    if (left is SimpleIdentifier) {
      if (left.name == 'state') isState = true;
    } else if (left is PropertyAccess) {
      if (left.propertyName.name == 'state' && left.target is ThisExpression) {
        isState = true;
      }
    }

    if (!isState) return;

    // Check if we are inside a Notifier
    final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
    if (enclosingClass == null) return;

    final notifierElement = enclosingClass.declaredFragment?.element;
    if (notifierElement == null ||
        !anyNotifierType.isAssignableFromType(notifierElement.thisType)) {
      return;
    }

    // Now check if it's wrapped in if (ref.mounted)
    if (!_isInsideMountedCheck(node)) {
      rule.reportAtNode(left);
    }
  }

  bool _isInsideMountedCheck(AstNode node) {
    var parent = node.parent;
    while (parent != null) {
      if (parent is IfStatement) {
        if (_isRefMounted(parent.expression)) {
          return true;
        }
      }
      parent = parent.parent;
    }
    return false;
  }

  bool _isRefMounted(Expression condition) {
    // Basic checks for ref.mounted or this.ref.mounted
    if (condition is PrefixedIdentifier) {
      return condition.prefix.name == 'ref' &&
          condition.identifier.name == 'mounted';
    }
    if (condition is PropertyAccess) {
      final target = condition.target;
      if (condition.propertyName.name == 'mounted') {
        if (target is SimpleIdentifier && target.name == 'ref') return true;
        if (target is PropertyAccess &&
            target.propertyName.name == 'ref' &&
            target.target is ThisExpression) {
          return true;
        }
      }
    }
    if (condition is BinaryExpression) {
      // Handle if (ref.mounted && ...)
      if (condition.operator.type.lexeme == '&&') {
        return _isRefMounted(condition.leftOperand) ||
            _isRefMounted(condition.rightOperand);
      }
    }
    if (condition is ParenthesizedExpression) {
      return _isRefMounted(condition.expression);
    }
    return false;
  }
}

class RefMountedFix extends ResolvedCorrectionProducer {
  RefMountedFix({required super.context});

  static const fix = FixKind(
    'ref_mounted_warning',
    DartFixKindPriority.standard,
    'Add if (ref.mounted) check',
  );

  @override
  FixKind get fixKind => fix;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = this.node;
    final statement = node.thisOrAncestorOfType<Statement>();
    if (statement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        range.node(statement),
        'if (ref.mounted) {\n  ${utils.getNodeText(statement)}\n}',
      );
    });
  }
}
