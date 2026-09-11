import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_provider.dart'; 

class SearchInputBar extends ConsumerStatefulWidget {
  const SearchInputBar({super.key});

  @override
  ConsumerState<SearchInputBar> createState() => _SearchInputBarState();
}

class _SearchInputBarState extends ConsumerState<SearchInputBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);

    return TextField(
      controller: _controller,
      onChanged: (value) {
        ref.read(searchQueryProvider.notifier).setQuery(value);
      },
      decoration: InputDecoration(
        hintText: 'Buscar producto por nombre o código...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  ref.read(searchQueryProvider.notifier).clear();
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}