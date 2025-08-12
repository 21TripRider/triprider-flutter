import 'package:flutter/material.dart';

class RentshopList extends StatelessWidget {
  const RentshopList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RentAppBar(),

      body: Column(children: [Sort(), Expanded(child: ListView())]),
    );
  }
}



class RentAppBar extends StatefulWidget implements PreferredSizeWidget {
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  const RentAppBar({super.key});

  @override
  State<RentAppBar> createState() => _RentAppBarState();
}

class _RentAppBarState extends State<RentAppBar> {
  @override
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        '오토바이 렌트',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      leading: IconButton(
        onPressed: Arrow_Back_ios_Pressed,
        icon: Icon(Icons.arrow_back_ios_new),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Arrow_Back_ios_Pressed() {
    Navigator.of(context).pop();
  }
}

class Sort extends StatefulWidget {
  const Sort({super.key});

  @override
  State<Sort> createState() => _SortState();
}

class _SortState extends State<Sort> {
  String selectedSort = '거리순';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() {
                selectedSort = value;
              });
            },
            itemBuilder:
                (BuildContext context) => [
              const PopupMenuItem(value: '거리순', child: Text('거리순')),
              const PopupMenuItem(value: '인기순', child: Text('인기순')),
            ],
            child: Row(
              children: [
                Text(
                  selectedSort,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.black),
              ],
            ),
          ),
        ],
      ),
    );
  }
}