import 'package:flutter_test/flutter_test.dart';
import 'package:heycar_app/story_service.dart';

void main(){
  test('StoryItem parses API payload and state',(){
    final item=StoryItem.fromJson({
      'id':'story-1',
      'title':'Çekici',
      'subtitle':'İlk çağrında indirim',
      'thumbnailUrl':'https://example.test/uploads/promos/thumb.jpg',
      'contentImageUrl':'https://example.test/uploads/promos/content.jpg',
      'badgeType':'discount',
      'badgeText':'%20',
      'ctaEnabled':true,
      'ctaText':'Yararlan',
      'actionType':'SERVICE',
      'actionTarget':'towing',
      'categoryId':'cat-1',
      'categorySlug':'towing',
      'categoryName':'Çekici',
      'categoryIcon':'towing',
      'sortOrder':10,
      'viewed':false,
      'opened':false,
      'clicked':false,
    });
    expect(item.id,'story-1');
    expect(item.actionType,'SERVICE');
    expect(item.actionTarget,'towing');
    expect(item.badgeText,'%20');
    expect(item.viewed,isFalse);

    final read=item.copyWith(viewed:true,opened:true,clicked:true);
    expect(read.viewed,isTrue);
    expect(read.opened,isTrue);
    expect(read.clicked,isTrue);
    expect(read.title,item.title);
  });
}
