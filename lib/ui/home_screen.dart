import 'package:flutter/material.dart';
import 'package:Saturn/api/deezer.dart';
import 'package:Saturn/api/definitions.dart';
import 'package:Saturn/api/player.dart';
import 'package:Saturn/main.dart';
import 'package:Saturn/ui/elements.dart';
import 'package:Saturn/ui/error.dart';
import 'package:Saturn/ui/menu.dart';
import 'package:Saturn/translations.i18n.dart';
import 'tiles.dart';
import 'details_screens.dart';
import '../settings.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SafeArea(child: Container()),
          Flexible(child: HomePageScreen(),)
        ],
      ),
    );
  }
}

class freezerTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset('assets/icon.png', width: 64, height: 64),
              Text(
                'Saturn',
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}



class HomePageScreen extends StatefulWidget {

  final HomePage homePage;
  final DeezerChannel channel;
  HomePageScreen({this.homePage, this.channel, Key key}): super(key: key);

  @override
  _HomePageScreenState createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  HomePage _homePage;
  bool _cancel = false;
  bool _error = false;

  void _loadChannel() async {
    debugPrint('Loading channel');
    HomePage _hp;
    try {
      _hp = await deezerAPI.getChannel(widget.channel.target);
      debugPrint('Channel loaded: $_hp');
    } catch (e, stackTrace) {
      debugPrint('Error loading channel: $e\n$stackTrace');
    }
    if (_hp == null) {
      debugPrint('Channel load failed');
      setState(() => _error = true);
      return;
    }
    setState(() {
      _homePage = _hp;
      _error = false;
    });
  }

  void _loadHomePage() async {
    debugPrint('Loading homepage from local storage');
    try {
      HomePage _hp = await HomePage().load();
      setState(() => _homePage = _hp);
      debugPrint('Homepage loaded from local storage: $_hp');
    } catch (e, stackTrace) {
      debugPrint('Error loading homepage from local storage: $e\n$stackTrace');
    }
    
    try {
      if (settings.offlineMode) await deezerAPI.authorize();
      debugPrint('Loading homepage from API');
      HomePage _hp = await deezerAPI.homePage();
      if (_hp != null) {
        if (_cancel) {
          debugPrint('Homepage load cancelled');
          return;
        }
        if (_hp.sections.isEmpty) {
          debugPrint('Homepage sections are empty');
          return;
        }
        setState(() => _homePage = _hp);
        await _homePage.save();
        debugPrint('Homepage loaded from API and saved to cache: $_hp');
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading homepage from API: $e\n$stackTrace');
    }
  }

  void _load() {
    if (widget.channel != null) {
      _loadChannel();
    } else if (widget.channel == null && widget.homePage == null) {
      _loadHomePage();
    } else if (widget.homePage.sections == null || widget.homePage.sections.isEmpty) {
      _loadHomePage();
    } else {
      debugPrint('Using existing homepage data');
      setState(() => _homePage = widget.homePage);
    }
  }

  @override
  void initState() {
    super.initState();
    debugPrint('Init state');
    _load();
  }

  @override
  void dispose() {
    _cancel = true;
    debugPrint('Disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_homePage == null) {
      debugPrint('Homepage is null, showing CircularProgressIndicator');
      return Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
        ),
      );
    }
    if (_error) {
      debugPrint('Error state, showing ErrorScreen');
      return ErrorScreen();
    }
    debugPrint('Building homepage with ${_homePage.sections.length} sections');
    return Column(
      children: List.generate(
        _homePage.sections.length,
        (i) {
          switch (_homePage.sections[i].layout) {
            case HomePageSectionLayout.ROW:
              return HomepageRowSection(_homePage.sections[i]);
            case HomePageSectionLayout.GRID:
              return HomePageGridSection(_homePage.sections[i]);
            default:
              return HomepageRowSection(_homePage.sections[i]);
          }
        },
      ),
    );
  }
}



class HomepageRowSection extends StatelessWidget {

  final HomePageSection section;
  HomepageRowSection(this.section);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          (section.title == "Mixes inspired by...")?'':(section.title)??'',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.w900
          ),
        ),
      ),
      subtitle: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(section.items.length + 1, (j) {
            //Has more items
            if (j == section.items.length) {
              if (section.hasMore ?? false) {
                return TextButton(
                  child: Text(
                    'Show more'.i18n,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20.0
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: freezerAppBar(section.title),
                      body: SingleChildScrollView(
                        child: HomePageScreen(
                          channel: DeezerChannel(target: section.pagePath)
                        )
                      ),
                    ),
                  )),
                );
              }
              return Container(height: 0, width: 0);
            }

            //Show item
            HomePageItem item = section.items[j];
            return HomePageItemWidget(item);
          }),
        ),
      )
    );
  }
}

class HomePageGridSection extends StatelessWidget {

  final HomePageSection section;
  HomePageGridSection(this.section);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
      title: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.0, horizontal: 6.0),
        child: Text(
          section.title??'',
          textAlign: TextAlign.left,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.w900
          ),
        ),
      ),
      subtitle: Wrap(
        alignment: WrapAlignment.spaceAround,
        children: List.generate(section.items.length, (i) {

          //Item
          return HomePageItemWidget(section.items[i]);
        }),
      ),
    );
  }
}




class HomePageItemWidget extends StatelessWidget {

  HomePageItem item;
  HomePageItemWidget(this.item);

  @override
  Widget build(BuildContext context) {

    switch (item.type) {
      case HomePageItemType.SMARTTRACKLIST:
        return SmartTrackListTile(
          item.value,
          onTap: () {
            playerHelper.playFromSmartTrackList(item.value);
          },
        );
      case HomePageItemType.FLOW:
        return FlowTile(
          item.value,
          onTap: () {
            playerHelper.playFromSmartTrackList(SmartTrackList(id: item.value.id));
          },
        );
      case HomePageItemType.ALBUM:
        return AlbumCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => AlbumDetails(item.value)
            ));
          },
          onHold: () {
            MenuSheet m = MenuSheet(context);
            m.defaultAlbumMenu(item.value);
          },
        );
      case HomePageItemType.ARTIST:
        return ArtistTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ArtistDetails(item.value)
            ));
          },
          onHold: () {
            MenuSheet m = MenuSheet(context);
            m.defaultArtistMenu(item.value);
          },
        );
      case HomePageItemType.PLAYLIST:
        return PlaylistCardTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => PlaylistDetails(item.value)
            ));
          },
          onHold: () {
            MenuSheet m = MenuSheet(context);
            m.defaultPlaylistMenu(item.value);
          },
        );
      case HomePageItemType.CHANNEL:
        return ChannelTile(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => Scaffold(
                  appBar: freezerAppBar(item.value.title.toString()),
                  body: SingleChildScrollView(
                    child: HomePageScreen(channel: item.value,)
                  ),
                )
            ));
          },
        );
      case HomePageItemType.SHOW:
        return ShowCard(
          item.value,
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => ShowScreen(item.value)
            ));
          },
        );
    }
    return Container(height: 0, width: 0);
  }
}
