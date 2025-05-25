// This source code is a part of Project Violet.
// Copyright (C) 2020-2025. violet-team. Licensed under the Apache-2.0 License.

import 'package:flutter/material.dart';

class RadioTile<T> extends StatefulWidget {
  const RadioTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.setGroupValue,
    required this.title,
    required this.subtitle,
    required this.onLongPress,
  });

  final T value;
  final T groupValue;
  final void Function(T) setGroupValue;
  final Widget title;
  final Widget subtitle;
  final void Function() onLongPress;

  @override
  State<RadioTile<T>> createState() => _RadioTileState<T>();
}

class _RadioTileState<T> extends State<RadioTile<T>> {
  bool _longPressing = false;

  @override
  Widget build(BuildContext context) {
    bool selected = widget.value == widget.groupValue;

    return AnimatedContainer(
      transform: Matrix4.identity()
        ..translate(300 / 2, 50 / 2)
        ..scale(_longPressing ? 0.95 : (selected ? 1.03 : 1.0))
        ..translate(-300 / 2, -50 / 2),
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 4,
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(3.0))),
          child: ListTile(
            leading: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 44,
                minHeight: 44,
                maxWidth: 44,
                maxHeight: 44,
              ),
              child: Radio<T>(
                value: widget.value,
                groupValue: widget.groupValue,
                materialTapTargetSize: MaterialTapTargetSize.padded,
                onChanged: (T? selected) {
                  setState(() {
                    _longPressing = false;
                    if (selected != null) {
                      widget.setGroupValue(selected);
                    }
                  });
                },
              ),
            ),
            title: widget.title,
            subtitle: widget.subtitle,
            dense: true,
          ),
          onTapDown: (details) {
            setState(() {
              _longPressing = true;
            });
          },
          onTap: () {
            setState(() {
              _longPressing = false;
              widget.setGroupValue(widget.value);
            });
          },
          onLongPress: () {
            setState(() {
              _longPressing = false;
              widget.onLongPress();
            });
          },
        ),
      ),
    );
  }
}
